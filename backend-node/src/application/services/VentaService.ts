/**
 * @fileoverview VentaService - Servicio de Orquestación de Ventas
 * Implementa el Saga Pattern para garantizar consistencia distribuida entre
 * el backend Node.js y el backend Python (Karel)
 *
 * Flujo crítico (HU-28, HU-29):
 * 1. Validar DTO y crear entidad
 * 2. Descontar stock en Python (IInventoryProvider)
 * 3. Persistir en Firestore (IVentaRepository)
 * 4. Si persistencia falla → Compensar en Python (compensar stock)
 * 5. Si hay controlados → Registrar auditoría (receta médica)
 */

import { Venta, LineaVenta, Pago, TipoPago, DatosReceta } from '@domain/entities/Venta';
import { Usuario } from '@domain/entities/Usuario';
import {
  CreateVentaDTO,
  validarCreateVentaDTO,
} from '@application/dtos/CreateVentaDTO';
import { IVentaRepository } from '@application/interfaces/IVentaRepository';
import { IInventoryProvider, MapperLineaDescontar } from '@domain/ports/IInventoryProvider';

/**
 * Excepciones personalizadas para el servicio
 */
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

/**
 * VentaService - Orquestador de Ventas con Saga Pattern
 *
 * Responsabilidades:
 * - HU-28: Crear venta inmutable
 * - HU-29: Deducción de inventario con Python (FEFO)
 * - HU-30: Auditoría de productos controlados
 * - HU-35: Anular ventas con reintegro de stock
 * - HU-39: Reportes financieros
 *
 * Dependencias inyectadas:
 * - ventaRepository: Persistencia en Firestore
 * - inventoryProvider: Comunicación con backend Python
 */
export class VentaService {
  /**
   * Constructor con inyección de dependencias
   * @param ventaRepository - Adaptador de persistencia (Firestore)
   * @param inventoryProvider - Adaptador de inventario (Python via HTTP)
   */
  constructor(
    private readonly ventaRepository: IVentaRepository,
    private readonly inventoryProvider: IInventoryProvider,
  ) {}

  /**
   * Crea una nueva venta siguiendo el Saga Pattern (HU-28, HU-29)
   *
   * Flujo detallado:
   * ┌─────────────────────────────────────────────────────────────┐
   * │ 1. VALIDACIÓN                                               │
   * │    - Validar DTO con Zod                                    │
   * │    - Crear entidad Venta inmutable                          │
   * │    - Generar folio único                                    │
   * └─────────────────────────────────────────────────────────────┘
   *              ↓
   * ┌─────────────────────────────────────────────────────────────┐
   * │ 2. DESCONTAR STOCK (SAGA STEP 1)                            │
   * │    - Llamar Python: POST /api/inventario/descontar          │
   * │    - Especificar lotes (FEFO)                               │
   * │    - Si falla → Retornar error (NO persistir)               │
   * │    - ✅ Éxito → Continuar                                   │
   * └─────────────────────────────────────────────────────────────┘
   *              ↓
   * ┌─────────────────────────────────────────────────────────────┐
   * │ 3. PERSISTIR EN FIRESTORE (SAGA STEP 2)                     │
   * │    - Guardar en colección: tickets_ventas                   │
   * │    - Documento ID: ventaId (folio)                          │
   * │    - Marcar como inmutable                                  │
   * │    - Si falla → Ejecutar COMPENSACIÓN                       │
   * └─────────────────────────────────────────────────────────────┘
   *              ↓
   * ┌─────────────────────────────────────────────────────────────┐
   * │ 4. AUDITORÍA DE RECETAS (Si hay controlados - HU-30)        │
   * │    - Persistir en colección: auditoria_recetas              │
   * │    - Datos médico + productos controlados                   │
   * │    - Referencias cruzadas para auditoría legal              │
   * └─────────────────────────────────────────────────────────────┘
   *              ↓
   *        ✅ VENTA COMPLETADA
   *
   * COMPENSACIÓN (Si falla paso 3):
   * ┌─────────────────────────────────────────────────────────────┐
   * │ - Llamar Python: POST /api/inventario/compensar             │
   * │ - Reintegrar stock descotado en paso 2                      │
   * │ - Si también falla → ERROR CRÍTICO (requiere intervención)  │
   * └─────────────────────────────────────────────────────────────┘
   *
   * @param usuario - Usuario que realiza la venta (autenticado)
   * @param createVentaDTO - DTO validado con Zod
   * @returns Venta creada y persistida
   * @throws {VentaServiceError} Si algo falla en el proceso
   * @throws {StockInsuficienteError} Si no hay stock en Python
   * @throws {CompensacionFallidaError} Si falla persistencia Y compensación
   */
  public async crearVenta(
    usuario: Usuario,
    createVentaDTO: CreateVentaDTO,
  ): Promise<Venta> {
    // ========================================
    // PASO 1: VALIDACIÓN
    // ========================================

    const ventaValidada = validarCreateVentaDTO(createVentaDTO);
    // Generar folio único: timestamp + random
    const ventaId = `V${Date.now()}${Math.random().toString(36).substring(2, 11)}`.toUpperCase();

    console.log(`[VentaService] Iniciando creación de venta ${ventaId}`);

    try {
      // Convertir DTO a entidades de dominio
      const lineas = ventaValidada.lineas.map(
        (lineaDTO) =>
          new LineaVenta(
            lineaDTO.codigoProducto,
            lineaDTO.nombreProducto,
            lineaDTO.cantidad,
            lineaDTO.precioUnitario,
            lineaDTO.esControlado,
            lineaDTO.lote,
          ),
      );

      const pagos = ventaValidada.pagos.map(
        (pagoDTO) =>
          new Pago(pagoDTO.tipo as TipoPago, pagoDTO.monto, pagoDTO.referencia),
      );

      let datosReceta: DatosReceta | undefined;
      if (ventaValidada.datosReceta) {
        datosReceta = new DatosReceta(
          ventaValidada.datosReceta.ciMedico,
          ventaValidada.datosReceta.nombreMedico,
          new Date(ventaValidada.datosReceta.fechaReceta),
        );
      }

      // Crear entidad inmutable
      const venta = Venta.crear(
        ventaId,
        usuario.getId(),
        lineas,
        pagos,
        ventaValidada.ivaPercentaje,
        datosReceta,
      );

      console.log(
        `[VentaService] Entidad Venta creada: ${venta.getId()} - Total: ${venta.getTotal()}`,
      );

      // ========================================
      // PASO 2: DESCONTAR STOCK EN PYTHON (SAGA STEP 1)
      // ========================================

      const lineasDescontar = MapperLineaDescontar.fromLineasVenta(
        venta.getLineas(),
      );

      console.log(
        `[VentaService] Descontando stock en Python para venta ${ventaId}...`,
      );

      let descontarResponse;
      try {
        descontarResponse = await this.inventoryProvider.descontarStock(
          ventaId,
          lineasDescontar,
        );
        console.log(
          `[VentaService] Stock descontado exitosamente: ${JSON.stringify(descontarResponse.detalles)}`,
        );
      } catch (errorPython: any) {
        // Si Python falla, no persistimos nada → sin necesidad de compensación
        console.error(
          `[VentaService] FALLO en descontar stock: ${errorPython.message}`,
        );

        if (
          errorPython.message &&
          errorPython.message.includes('stock insuficiente')
        ) {
          throw new StockInsuficienteError({
            ventaId,
            lineas: lineasDescontar,
            error: errorPython.message,
          });
        }

        throw new VentaServiceError(
          `Error al descontar stock en Python: ${errorPython.message}`,
          'DESCUENTO_FALLIDO',
        );
      }

      // ========================================
      // PASO 3: PERSISTIR EN FIRESTORE (SAGA STEP 2)
      // ========================================

      console.log(`[VentaService] Persistiendo venta en Firestore...`);

      let ventaPersistida: Venta;
      try {
        ventaPersistida = await this.ventaRepository.crear(venta);
        ventaPersistida.marcarComoProcesada();
        console.log(`[VentaService] Venta persistida exitosamente: ${ventaId}`);
      } catch (errorPersistencia: any) {
        // COMPENSACIÓN: Si Firestore falla, reintegrar stock en Python
        console.error(
          `[VentaService] FALLO en Firestore. Iniciando compensación...`,
        );

        try {
          await this.inventoryProvider.compensar(ventaId, lineasDescontar);
          console.log(
            `[VentaService] Compensación ejecutada exitosamente para venta ${ventaId}`,
          );
        } catch (errorCompensacion: any) {
          // CRÍTICO: Persistencia falló Y compensación falló
          console.error(
            `[VentaService] FALLO CRÍTICO en compensación: ${errorCompensacion.message}`,
          );
          throw new CompensacionFallidaError(ventaId, errorCompensacion);
        }

        // Compensación exitosa pero persistencia falló
        throw new VentaServiceError(
          `Error al persistir venta en Firestore (stock compensado): ${errorPersistencia.message}`,
          'PERSISTENCIA_FALLIDA',
        );
      }

      // ========================================
      // PASO 4: AUDITORÍA DE RECETAS (HU-30)
      // ========================================

      if (venta.getTieneProductosControlados()) {
        console.log(
          `[VentaService] Registrando auditoría de productos controlados...`,
        );

        const productosControlados = venta
          .getLineas()
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
          console.log(
            `[VentaService] Auditoría de receta registrada para venta ${ventaId}`,
          );
        } catch (errorAuditoria: any) {
          console.error(
            `[VentaService] Error registrando auditoría (no es crítico): ${errorAuditoria.message}`,
          );
        }
      }

      console.log(
        `[VentaService] ✅ Venta completada exitosamente: ${ventaId}`,
      );
      return ventaPersistida;
    } catch (error: any) {
      console.error(`[VentaService] Error general al crear venta: ${error.message}`);
      throw error;
    }
  }

  /**
   * Obtiene una venta por su ID (folio)
   * @param ventaId - ID de la venta
   * @returns Venta recuperada
   */
  public async obtenerVenta(ventaId: string): Promise<Venta> {
    return await this.ventaRepository.obtenerPorId(ventaId);
  }

  /**
   * Obtiene ventas de un usuario (HU-35: Por turno/UID)
   * @param usuarioId - UID del usuario
   * @param filtros - Opciones de paginación
   * @returns Array de ventas del usuario
   */
  public async obtenerVentasDelUsuario(
    usuarioId: string,
    filtros?: Partial<{ limit: number; offset: number }>,
  ): Promise<Venta[]> {
    return await this.ventaRepository.obtenerPorUsuario(usuarioId, filtros);
  }

  /**
   * Anula una venta (HU-35: Anulación de tickets)
   * Ejecuta reintegro de stock en Python
   *
   * @param ventaId - ID de la venta a anular
   * @param razon - Motivo de la anulación
   * @param usuarioId - UID del usuario que anula
   * @returns Venta anulada
   */
  public async anularVenta(
    ventaId: string,
    razon: string,
    usuarioId: string,
  ): Promise<Venta> {
    console.log(`[VentaService] Anulando venta ${ventaId}...`);

    try {
      // 1. Obtener venta actual
      const ventaActual = await this.ventaRepository.obtenerPorId(ventaId);

      // 2. Preparar líneas para compensación
      const lineasCompensanr = MapperLineaDescontar.fromLineasVenta(
        ventaActual.getLineas(),
      );

      // 3. Reintegrar stock en Python
      await this.inventoryProvider.compensar(ventaId, lineasCompensanr);

      // 4. Marcar como anulada en Firestore
      const ventaAnulada = await this.ventaRepository.anular(
        ventaId,
        razon,
        usuarioId,
      );

      console.log(`[VentaService] Venta ${ventaId} anulada exitosamente`);
      return ventaAnulada;
    } catch (error: any) {
      console.error(`[VentaService] Error anulando venta: ${error.message}`);
      throw new VentaServiceError(
        `Error al anular venta ${ventaId}: ${error.message}`,
        'ANULACION_FALLIDA',
      );
    }
  }

  /**
   * Obtiene estadísticas de ventas (HU-39: KPIs financieros)
   * @param fechaInicio - Inicio del período
   * @param fechaFin - Fin del período
   * @returns Estadísticas del período
   */
  public async obtenerEstadisticas(
    fechaInicio: Date,
    fechaFin: Date,
  ): Promise<any> {
    return await this.ventaRepository.obtenerEstadisticas(
      fechaInicio,
      fechaFin,
    );
  }

  /**
   * Obtiene auditoria de productos controlados (HU-30, HU-39)
   * @param filtros - Criterios de búsqueda
   * @returns Array de registros de auditoría
   */
  public async obtenerAuditoriaRecetas(filtros?: any): Promise<any[]> {
    return await this.ventaRepository.obtenerAuditoriaRecetas(filtros);
  }
}
