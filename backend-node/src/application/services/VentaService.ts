/**
 * @fileoverview VentaService - Servicio de Orquestación de Ventas
 * Implementa el Saga Pattern completo con Python (HU-29, HU-40)
 */

import { Venta, LineaVenta, Pago, TipoPago, DatosReceta } from '@domain/entities/Venta';
import { Usuario } from '@domain/entities/Usuario';
import {
  CreateVentaDTO,
  validarCreateVentaDTO,
} from '@application/dtos/CreateVentaDTO';
import { IVentaRepository } from '@application/interfaces/IVentaRepository';
import { IInventoryProvider, MapperLineaDescontar } from '@domain/ports/IInventoryProvider';

export class VentaServiceError extends Error {
  constructor(message: string, public code: string) {
    super(message);
    this.name = 'VentaServiceError';
  }
}

export class StockInsuficienteError extends VentaServiceError {
  constructor(detalles: any) {
    super('Stock insuficiente para completar la venta', 'STOCK_INSUFICIENTE');
    this.detalles = detalles;
  }
  detalles: any;
}

export class CompensacionFallidaError extends VentaServiceError {
  constructor(ventaId: string, original: Error) {
    super(
      `Fallo crítico: venta persistida pero compensación en Python falló. Venta: ${ventaId}. Error: ${original.message}`,
      'COMPENSACION_FALLIDA',
    );
    this.ventaId = ventaId;
    this.errorOriginal = original;
  }
  ventaId: string;
  errorOriginal: Error;
}

export class VentaService {
  constructor(
    private readonly ventaRepository: IVentaRepository,
    private readonly inventoryProvider: IInventoryProvider,
  ) {}

  public async crearVenta(
    usuario: Usuario,
    createVentaDTO: CreateVentaDTO,
  ): Promise<Venta> {

    const ventaValidada = validarCreateVentaDTO(createVentaDTO);
    const ventaId = `V${Date.now()}${Math.random().toString(36).substring(2, 11)}`.toUpperCase();

    console.log(`[VentaService] ⚡ Procesando venta ${ventaId} para ${usuario.getNombre()}`);

    try {
      // 1. CONSTRUIR ENTIDAD VENTA
      const lineas = ventaValidada.lineas.map(
        (l) => new LineaVenta(
          l.codigoProducto,
          l.nombreProducto,
          l.cantidad,
          l.precioUnitario,
          l.esControlado,
          l.lote,
        )
      );

      const pagos = ventaValidada.pagos.map(
        (p) => new Pago(p.tipo as TipoPago, p.monto, p.referencia)
      );

      let datosReceta: DatosReceta | undefined;
      if (ventaValidada.datosReceta) {
        datosReceta = new DatosReceta(
          ventaValidada.datosReceta.ciMedico,
          ventaValidada.datosReceta.nombreMedico,
          new Date(ventaValidada.datosReceta.fechaReceta),
        );
      }

      const venta = Venta.crear(
        ventaId,
        usuario.getId(),
        lineas,
        pagos,
        ventaValidada.ivaPercentaje,
        ventaValidada.montoRecibido,
        datosReceta,
      );

      // ============================================================
      // SAGA STEP 1: DESCONTAR STOCK EN PYTHON (HU-29, HU-40)
      // ============================================================
      console.log(`[VentaService] 📦 SAGA STEP 1: Descontando stock en Python...`);

      const lineasDescontar = MapperLineaDescontar.fromLineasVenta(venta.getLineas());
      const datosRecetaDescuento = venta.getDatosReceta()
        ? {
            ciMedico: venta.getDatosReceta()!.getCiMedico(),
            nombreMedico: venta.getDatosReceta()!.getNombreMedico(),
            fechaReceta: venta.getDatosReceta()!.getFechaReceta().toISOString(),
          }
        : undefined;

      let resultadoDescuento: any;
      try {
        resultadoDescuento = await this.inventoryProvider.descontarStock(
          ventaId,
          lineasDescontar,
          datosRecetaDescuento,
        );
        console.log(`[VentaService] ✅ Stock descontado en Python:`, JSON.stringify(resultadoDescuento));
      } catch (errorStock: any) {
        // Si Python rechaza por stock insuficiente, abortar sin guardar en Firestore
        console.error(`[VentaService] ❌ Error en descuento de stock: ${errorStock.message}`);
        if (errorStock.message?.toLowerCase().includes('stock insuficiente')) {
          throw new StockInsuficienteError({ mensaje: errorStock.message });
        }
        throw new VentaServiceError(
          `Error al descontar stock: ${errorStock.message}`,
          'STOCK_ERROR',
        );
      }

      // Si el descuento en inventario fue exitoso, la venta ya puede consolidarse.
      venta.marcarComoProcesada();

      // ============================================================
      // SAGA STEP 2: PERSISTIR EN FIRESTORE
      // ============================================================
      console.log(`[VentaService] 🔥 SAGA STEP 2: Guardando en Firestore...`);

      let ventaPersistida: Venta;
      try {
        ventaPersistida = await this.ventaRepository.crear(venta);
        console.log(`[VentaService] ✅ Venta ${ventaId} guardada en Firestore.`);
      } catch (errorPersistencia: any) {
        // Firestore falló DESPUÉS de descontar — ejecutar compensación
        console.error(`[VentaService] ❌ Firestore falló, iniciando compensación...`);
        try {
          await this.inventoryProvider.compensar(ventaId, lineasDescontar);
          console.log(`[VentaService] ✅ Compensación exitosa, stock reintegrado.`);
        } catch (errorCompensacion: any) {
          // FALLO CRÍTICO: stock descontado pero no se pudo reintegrar
          console.error(`[VentaService] 🚨 FALLO CRÍTICO en compensación: ${errorCompensacion.message}`);
          throw new CompensacionFallidaError(ventaId, errorCompensacion);
        }
        throw new VentaServiceError(
          `Error Firestore: ${errorPersistencia.message}`,
          'PERSISTENCIA_FALLIDA',
        );
      }

      // ============================================================
      // PASO 3: AUDITORÍA DE RECETAS (HU-38)
      // ============================================================
      if (venta.getTieneProductosControlados()) {
        console.log(`[VentaService] 📋 Registrando auditoría de receta...`);
        const productosControlados = venta.getLineas()
          .filter((l) => l.esProductoControlado())
          .map((l) => ({
            codigo: l.getCodigoProducto(),
            nombre: l.getNombreProducto(),
            cantidad: l.getCantidad(),
            lote: l.getLote() || 'sin-lote',
          }));

        try {
          await this.ventaRepository.registrarRecetaControlada(
            ventaId,
            {
              ciMedico: venta.getDatosReceta()!.getCiMedico(),
              nombreMedico: venta.getDatosReceta()!.getNombreMedico(),
              fechaReceta: venta.getDatosReceta()!.getFechaReceta(),
            },
            productosControlados,
          );
        } catch (e) {
          console.warn(`[VentaService] ⚠️ No se pudo registrar auditoría, pero la venta es válida.`);
        }
      }

      return ventaPersistida;

    } catch (error: any) {
      console.error(`[VentaService] Fallo: ${error.message}`);
      throw error;
    }
  }

  public async obtenerVenta(ventaId: string): Promise<Venta> {
    return await this.ventaRepository.obtenerPorId(ventaId);
  }

  public async obtenerVentasDelUsuario(usuarioId: string, filtros?: any): Promise<Venta[]> {
    return await this.ventaRepository.obtenerPorUsuario(usuarioId, filtros);
  }

  public async anularVenta(ventaId: string, razon: string, usuarioId: string): Promise<Venta> {
    // Al anular, reintegrar stock en Python
    const venta = await this.ventaRepository.obtenerPorId(ventaId);
    const lineasDescontar = MapperLineaDescontar.fromLineasVenta(venta.getLineas());

    try {
      await this.inventoryProvider.compensar(ventaId, lineasDescontar);
      console.log(`[VentaService] ✅ Stock reintegrado por anulación de ${ventaId}`);
    } catch (e: any) {
      console.error(`[VentaService] ⚠️ No se pudo reintegrar stock al anular: ${e.message}`);
    }

    return await this.ventaRepository.anular(ventaId, razon, usuarioId);
  }

  public async obtenerEstadisticas(fechaInicio: Date, fechaFin: Date): Promise<any> {
    return await this.ventaRepository.obtenerEstadisticas(fechaInicio, fechaFin);
  }

  public async obtenerAuditoriaRecetas(filtros?: any): Promise<any[]> {
    return await this.ventaRepository.obtenerAuditoriaRecetas(filtros);
  }
}