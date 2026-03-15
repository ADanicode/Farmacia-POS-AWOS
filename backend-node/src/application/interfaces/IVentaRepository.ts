/**
 * @fileoverview Puerto IVentaRepository - Interfaz de persistencia de ventas
 * Define el contrato para almacenar y recuperar ventas de Firestore
 * Esta es una interfaz de salida (puerto) de la capa de Aplicación
 */

import { Venta } from '@domain/entities/Venta';
import { CreateVentaDTO } from '@application/dtos/CreateVentaDTO';

/**
 * Interface para filtros en búsquedas de ventas
 */
export interface IFiltrosVenta {
  usuarioId?: string;
  fechaInicio?: Date;
  fechaFin?: Date;
  estado?: 'pendiente' | 'procesada' | 'anulada';
  limit?: number;
  offset?: number;
}

/**
 * Interface para resultados paginados de ventas
 */
export interface IPaginacionVentas {
  ventas: Venta[];
  total: number;
  pagina: number;
  paginas: number;
}

/**
 * Interface para auditoria de cambios en ventas
 */
export interface IAuditoriaVenta {
  ventaId: string;
  tipo: 'creacion' | 'modificacion' | 'anulacion';
  usuarioId: string;
  cambios: Record<string, any>;
  timestamp: Date;
  razon?: string;
}

/**
 * Puerto de Persistencia: IVentaRepository
 * Responsabilidades:
 * 1. Crear ventas inmutables (HU-28)
 * 2. Persistir datos de recetas (HU-30, auditoría médica)
 * 3. Anular ventas con reintegro de stock (HU-35)
 * 4. Consultar ventas por turno/usuario (HU-35)
 * 5. Trazabilidad de lotes (FEFO - HU-40)
 *
 * Implementaciones:
 * - FirestoreVentaRepository (producción - colecciones: tickets_ventas, auditoria_recetas)
 * - MockVentaRepository (tests)
 */
export interface IVentaRepository {
  /**
   * Crea una nueva venta inmutable en Firestore (HU-28)
   * Colección: tickets_ventas
   *
   * @param venta - Entidad Venta completamente validada
   * @returns Venta persistida con ID generado
   * @throws {Error} Si la persistencia falla
   *
   * Nota: Las ventas son INMUTABLES. Esta operación ejecuta una única vez
   * como parte del Saga Pattern. Si falla, se ejecuta compensación.
   */
  crear(venta: Venta): Promise<Venta>;

  /**
   * Obtiene una venta por su ID (folio)
   * @param ventaId - ID de la venta
   * @returns Venta recuperada
   * @throws {NotFoundError} Si la venta no existe
   */
  obtenerPorId(ventaId: string): Promise<Venta>;

  /**
   * Obtiene todas las ventas de un usuario (HU-35: Consulta de ventas por turno)
   * @param usuarioId - UID del usuario
   * @param filtros - Opciones de paginación y filtrado
   * @returns Array de ventas del usuario
   */
  obtenerPorUsuario(
    usuarioId: string,
    filtros?: Partial<IFiltrosVenta>,
  ): Promise<Venta[]>;

  /**
   * Obtiene ventas con paginación y filtrado
   * Útil para reportes administrativos (HU-35, HU-39)
   *
   * @param filtros - Criterios de búsqueda
   * @returns Ventas paginadas con metadatos
   */
  listar(filtros: IFiltrosVenta): Promise<IPaginacionVentas>;

  /**
   * Obtiene ventas procesadas en un rango de fechas (HU-35: Resumen diario)
   * Usado para KPIs y reportes financieros (HU-39)
   *
   * @param fechaInicio - Fecha de inicio (inclusive)
   * @param fechaFin - Fecha de fin (inclusive)
   * @returns Array de ventas en ese período
   */
  obtenerPorPeriodo(fechaInicio: Date, fechaFin: Date): Promise<Venta[]>;

  /**
   * Anula una venta existente (HU-35: Anulación de tickets)
   * Marca como 'anulada' sin eliminar el registro (auditoría)
   * Ejecuta reintegro de stock en el backend de Python
   *
   * @param ventaId - ID de la venta a anular
   * @param razon - Motivo de la anulación (auditoría)
   * @param usuarioId - UID del usuario que anula
   * @returns Venta anulada
   * @throws {NotFoundError} Si la venta no existe
   * @throws {Error} Si la venta ya está anulada
   */
  anular(
    ventaId: string,
    razon: string,
    usuarioId: string,
  ): Promise<Venta>;

  /**
   * Registra una receta médica en auditoría (HU-30: Auditoría de recetas retenidas)
   * Colección: auditoria_recetas (separada de tickets_ventas)
   *
   * Invocado cuando hay productos controlados en la venta
   * Datos capturados: CI médico, nombre, fecha, productos controlados, folio de venta
   *
   * @param ventaId - ID de la venta (referencia)
   * @param datosReceta - Datos del médico prescriptor
   * @param productosControlados - Array de productos controlados vendidos
   * @returns ID del registro de auditoría creado
   * @throws {Error} Si la auditoría falla
   */
  registrarRecetaControlada(
    ventaId: string,
    datosReceta: {
      ciMedico: string;
      nombreMedico: string;
      fechaReceta: Date;
    },
    productosControlados: Array<{
      codigo: string;
      nombre: string;
      cantidad: number;
      lote: string;
    }>,
  ): Promise<string>;

  /**
   * Obtiene auditoría de recetas controladas (HU-30, HU-39: Reporte sanitario)
   *
   * @param filtros - Criterios de búsqueda
   * @returns Historial de productos controlados vendidos
   */
  obtenerAuditoriaRecetas(
    filtros?: Partial<{
      fechaInicio: Date;
      fechaFin: Date;
      ciMedico: string;
      limit: number;
      offset: number;
    }>,
  ): Promise<any[]>;

  /**
   * Busca ventas por lote de medicamento (Trazabilidad FEFO - HU-31, HU-40)
   * Permite rastrear dónde se despachó cada lote
   * Útil para retiros de productos
   *
   * @param lote - Código del lote
   * @returns Array de ventas que incluyen ese lote
   */
  obtenerPorLote(lote: string): Promise<Venta[]>;

  /**
   * Registra cambios en venta para auditoría (trazabilidad)
   * No se usa internamente (ventas son inmutables), solo para anulaciones
   *
   * @param auditoria - Datos de auditoría
   * @returns ID del registro creado
   */
  registrarAuditoria(auditoria: IAuditoriaVenta): Promise<string>;

  /**
   * Obtiene estadísticas de ventas (HU-39: KPIs financieros)
   *
   * @param fechaInicio - Inicio del período
   * @param fechaFin - Fin del período
   * @returns Estadísticas: total, cantidad de ventas, ticket promedio, etc
   */
  obtenerEstadisticas(
    fechaInicio: Date,
    fechaFin: Date,
  ): Promise<{
    totalVentas: number;
    cantidadVentas: number;
    ticketPromedio: number;
    ventasMayoreMenor: { mayor: Venta; menor: Venta };
    ventasPorMetodo: Record<string, number>;
  }>;

  /**
   * Verifica si una venta existe (validación rápida)
   * @param ventaId - ID a verificar
   * @returns true si existe
   */
  existe(ventaId: string): Promise<boolean>;
}
