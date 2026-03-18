/**
 * @fileoverview VentaService - Servicio de Orquestación de Ventas
 * Implementa el Saga Pattern con BYPASS TEMPORAL de Python para desarrollo.
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

  /**
   * Crea una nueva venta (HU-28, HU-29)
   * NOTA: Se ha desactivado temporalmente la conexión con Python para evitar Timeouts en YaRC.
   */
  public async crearVenta(
    usuario: Usuario,
    createVentaDTO: CreateVentaDTO,
  ): Promise<Venta> {
    
    // 1. VALIDACIÓN Y PREPARACIÓN
    const ventaValidada = validarCreateVentaDTO(createVentaDTO);
    const ventaId = `V${Date.now()}${Math.random().toString(36).substring(2, 11)}`.toUpperCase();

    console.log(`\x1b[36m%s\x1b[0m`, `[VentaService] ⚡ Procesando venta ${ventaId} para ${usuario.getNombre()}`);

    try {
      const lineas = ventaValidada.lineas.map(
        (l) => new LineaVenta(l.codigoProducto, l.nombreProducto, l.cantidad, l.precioUnitario, l.esControlado, l.lote)
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

      const venta = Venta.crear(ventaId, usuario.getId(), lineas, pagos, ventaValidada.ivaPercentaje, datosReceta);

      // ============================================================
      // ⚠️ PASO 2: DESCONTAR STOCK EN PYTHON (BYPASS ACTIVO)
      // ============================================================
      console.log(`\x1b[33m%s\x1b[0m`, `[VentaService] 🚧 MODO DESARROLLO: Saltando conexión con Python...`);
      
      /* // Comentado para evitar que YaRC se quede cargando infinitamente
      const lineasDescontar = MapperLineaDescontar.fromLineasVenta(venta.getLineas());
      await this.inventoryProvider.descontarStock(ventaId, lineasDescontar);
      */

      // ============================================================
      // PASO 3: PERSISTIR EN FIRESTORE (SAGA STEP 2)
      // ============================================================
      console.log(`[VentaService] Guardando en Firestore colección 'tickets_ventas'...`);

      let ventaPersistida: Venta;
      try {
        ventaPersistida = await this.ventaRepository.crear(venta);
        console.log(`\x1b[32m%s\x1b[0m`, `[VentaService] ✅ ÉXITO: Venta ${ventaId} guardada.`);
      } catch (errorPersistencia: any) {
        console.error(`[VentaService] Error al guardar en base de datos: ${errorPersistencia.message}`);
        throw new VentaServiceError(`Error Firestore: ${errorPersistencia.message}`, 'PERSISTENCIA_FALLIDA');
      }

      // ============================================================
      // PASO 4: AUDITORÍA DE RECETAS (HU-30)
      // ============================================================
      if (venta.getTieneProductosControlados()) {
        console.log(`[VentaService] Registrando auditoría de receta...`);
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
          console.warn(`[VentaService] No se pudo registrar auditoría, pero la venta es válida.`);
        }
      }

      return ventaPersistida;
    } catch (error: any) {
      console.error(`[VentaService] Fallo crítico: ${error.message}`);
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
    // Nota: Aquí también se debería comentar la compensación de stock si Python está apagado
    return await this.ventaRepository.anular(ventaId, razon, usuarioId);
  }

  public async obtenerEstadisticas(fechaInicio: Date, fechaFin: Date): Promise<any> {
    return await this.ventaRepository.obtenerEstadisticas(fechaInicio, fechaFin);
  }

  public async obtenerAuditoriaRecetas(filtros?: any): Promise<any[]> {
    return await this.ventaRepository.obtenerAuditoriaRecetas(filtros);
  }
}
