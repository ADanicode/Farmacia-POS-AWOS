/**
 * @fileoverview ReporteService - Generación de reportes de ventas y auditoría
 * Implementa HU-35 (Ventas por turno), HU-38 (Auditoría de recetas), HU-39 (Resumen financiero)
 */

import { IVentaRepository } from '@application/interfaces/IVentaRepository';

/**
 * Interfaz para datos de resumen financiero
 */
export interface IResumenFinanciero {
  fecha: string;
  totalVentas: number;
  cantidadVentas: number;
  ticketPromedio: number;
  ventasMax: number;
  ventasMin: number;
  ventasPorMetodoPago: Record<string, {
    cantidad: number;
    monto: number;
    porcentaje: number;
  }>;
  productosMasVendidos?: Array<{
    codigo: string;
    nombre: string;
    cantidadTotal: number;
    ingresoTotal: number;
  }>;
}

/**
 * Interfaz para datos de auditoría de receta
 */
export interface IRegistroAuditoria {
  ventaId: string;
  fechaVenta: Date;
  medico: {
    ci: string;
    nombre: string;
  };
  productosControlados: Array<{
    codigo: string;
    nombre: string;
    cantidad: number;
    lote: string;
  }>;
  usuario: {
    uid: string;
    nombre: string;
  };
}

/**
 * ReporteService - Orquestador de reportes
 * Responsabilidades:
 * - HU-35: Ventas por turno/UID del usuario
 * - HU-38: Auditoría de ventas de productos controlados
 * - HU-39: Resumen financiero diario con KPIs
 */
export class ReporteService {
  /**
   * Constructor con inyección de dependencias
   * @param ventaRepository - Puerto de acceso a datos de ventas
   */
  constructor(private readonly ventaRepository: IVentaRepository) {}

  /**
   * Obtiene todas las ventas de un usuario en un período (HU-35)
   * Útil para ver historial de ventas por turno del vendedor/cajero
   *
   * @param usuarioId - UID del usuario
   * @param filtros - Opciones de paginación y período
   * @returns Array de ventas del usuario con metadata
   */
  public async obtenerVentasPorTurno(
    usuarioId: string,
    filtros?: Partial<{
      fechaInicio: Date;
      fechaFin: Date;
      limit: number;
      offset: number;
    }>,
  ): Promise<{
    ventas: any[];
    totalVentas: number;
    cantidadRegistros: number;
    subtotalPeriodo: number;
    ivaPeriodo: number;
    totalPeriodo: number;
    metadata: {
      usuarioId: string;
      periodo: { inicio: string; fin: string };
      fechaReporte: string;
    };
  }> {
    try {
      console.log(
        `[ReporteService] Obteniendo ventas por turno para usuario ${usuarioId}`,
      );

      let fechaInicio = filtros?.fechaInicio;
      let fechaFin = filtros?.fechaFin;

      // Si no se especifican fechas, usar el día actual
      if (!fechaInicio || !fechaFin) {
        const hoy = new Date();
        hoy.setHours(0, 0, 0, 0);
        fechaInicio = fechaInicio || hoy;

        const manana = new Date(hoy);
        manana.setDate(manana.getDate() + 1);
        fechaFin = fechaFin || manana;
      }

      // Obtener ventas del usuario en el período
      const ventasDelPeriodo = await this.ventaRepository.obtenerPorUsuario(
        usuarioId,
        {
          limit: filtros?.limit || 100,
          offset: filtros?.offset || 0,
        },
      );

      // Filtrar por fecha
      const ventasFiltradas = ventasDelPeriodo.filter((v) => {
        const fechaVenta = v.getFechaVenta();
        return fechaVenta >= fechaInicio! && fechaVenta <= fechaFin!;
      });

      // Calcular agregaciones
      const totalVentas = ventasFiltradas.reduce(
        (sum, v) => sum + v.getTotal(),
        0,
      );
      const ivaPeriodo = ventasFiltradas.reduce(
        (sum, v) => sum + v.getIVA(),
        0,
      );
      const subtotalPeriodo = ventasFiltradas.reduce(
        (sum, v) => sum + v.getSubtotal(),
        0,
      );

      return {
        ventas: ventasFiltradas.map((v) => ({
          ventaId: v.getId(),
          folio: v.getId(),
          fecha: v.getFechaVenta().toISOString(),
          total: v.getTotal(),
          estado: v.getEstado(),
          cantidadProductos: v.getLineas().length,
          metodoPago: v.getPagos().length > 1 ? 'mixto' : v.getPagos()[0]?.getTipo(),
        })),
        totalVentas,
        cantidadRegistros: ventasFiltradas.length,
        subtotalPeriodo,
        ivaPeriodo,
        totalPeriodo: totalVentas,
        metadata: {
          usuarioId,
          periodo: {
            inicio: fechaInicio.toISOString(),
            fin: fechaFin.toISOString(),
          },
          fechaReporte: new Date().toISOString(),
        },
      };
    } catch (error: any) {
      console.error(
        `[ReporteService] Error obteniendo ventas por turno: ${error.message}`,
      );
      throw new Error(
        `Error generando reporte de ventas por turno: ${error.message}`,
      );
    }
  }

  /**
   * Obtiene auditoría de productos controlados (HU-38)
   * Registro legal de venta de medicamentos de control especial
   *
   * @param filtros - Criterios de búsqueda (fecha, médico, cantidad)
   * @returns Array de registros de auditoría con detalles de recetas
   */
  public async obtenerAuditoriaRecetas(
    filtros?: Partial<{
      fechaInicio: Date;
      fechaFin: Date;
      ciMedico?: string;
      limit: number;
      offset: number;
    }>,
  ): Promise<{
    registros: IRegistroAuditoria[];
    totalRegistros: number;
    totalProductosControlados: number;
    medicos: Array<{ ci: string; nombre: string; countProductos: number }>;
    metadata: {
      periodo: { inicio: string; fin: string };
      fechaReporte: string;
    };
  }> {
    try {
      console.log(`[ReporteService] Obteniendo auditoría de recetas`);

      let fechaInicio = filtros?.fechaInicio;
      let fechaFin = filtros?.fechaFin;

      // Si no se especifican fechas, usar los últimos 30 días
      if (!fechaInicio || !fechaFin) {
        const hoy = new Date();
        fechaFin = fechaFin || hoy;

        const hace30Dias = new Date(hoy);
        hace30Dias.setDate(hace30Dias.getDate() - 30);
        fechaInicio = fechaInicio || hace30Dias;
      }

      // Obtener auditoría de recetas
      const auditoria = await this.ventaRepository.obtenerAuditoriaRecetas({
        fechaInicio,
        fechaFin,
        ciMedico: filtros?.ciMedico,
        limit: filtros?.limit || 500,
        offset: filtros?.offset || 0,
      });

      // Agrupar por médico
      const medicosMap = new Map<string, { ci: string; nombre: string; countProductos: number }>();
      let totalProductos = 0;

      auditoria.forEach((registro: any) => {
        const ci = registro.datosReceta.ciMedico;
        const nombre = registro.datosReceta.nombreMedico;
        const countProductos = registro.productosControlados.length;

        if (medicosMap.has(ci)) {
          const existing = medicosMap.get(ci)!;
          existing.countProductos += countProductos;
        } else {
          medicosMap.set(ci, { ci, nombre, countProductos });
        }

        totalProductos += countProductos;
      });

      return {
        registros: auditoria.map((reg: any) => ({
          ventaId: reg.ventaId,
          fechaVenta: new Date(reg.fechaRegistro.toDate()),
          medico: {
            ci: reg.datosReceta.ciMedico,
            nombre: reg.datosReceta.nombreMedico,
          },
          productosControlados: reg.productosControlados,
          usuario: {
            uid: reg.usuarioId || 'N/A',
            nombre: reg.usuarioNombre || 'N/A',
          },
        })),
        totalRegistros: auditoria.length,
        totalProductosControlados: totalProductos,
        medicos: Array.from(medicosMap.values()),
        metadata: {
          periodo: {
            inicio: fechaInicio.toISOString(),
            fin: fechaFin.toISOString(),
          },
          fechaReporte: new Date().toISOString(),
        },
      };
    } catch (error: any) {
      console.error(
        `[ReporteService] Error obteniendo auditoría de recetas: ${error.message}`,
      );
      throw new Error(
        `Error generando reporte de auditoría: ${error.message}`,
      );
    }
  }

  /**
   * Obtiene resumen financiero del día (HU-39)
   * KPIs financieros: total ventas, cantidad, ticket promedio, desglose por método
   *
   * @param fecha - Fecha de reporte (default: hoy)
   * @returns Resumen con estadísticas financieras detalladas
   */
  public async obtenerResumenFinancieroDelDia(
    fecha?: Date,
  ): Promise<IResumenFinanciero> {
    try {
      const reportDate = fecha || new Date();
      console.log(
        `[ReporteService] Generando resumen financiero para ${reportDate.toDateString()}`,
      );

      // Establecer rango de fecha (00:00:00 a 23:59:59)
      const fechaInicio = new Date(reportDate);
      fechaInicio.setHours(0, 0, 0, 0);

      const fechaFin = new Date(reportDate);
      fechaFin.setHours(23, 59, 59, 999);

      // Obtener estadísticas del período
      const estadisticas = await this.ventaRepository.obtenerEstadisticas(
        fechaInicio,
        fechaFin,
      );

      // Si no hay ventas, retornar resumen vacío
      if (estadisticas.cantidadVentas === 0) {
        return {
          fecha: reportDate.toISOString().split('T')[0],
          totalVentas: 0,
          cantidadVentas: 0,
          ticketPromedio: 0,
          ventasMax: 0,
          ventasMin: 0,
          ventasPorMetodoPago: {},
        };
      }

      // Obtener todas las ventas del día para análisis detallado
      const ventasDelDia = await this.ventaRepository.obtenerPorPeriodo(
        fechaInicio,
        fechaFin,
      );

      // Desglose por método de pago
      const ventasPorMetodo: Record<string, { cantidad: number; monto: number }> = {};
      ventasDelDia.forEach((venta) => {
        venta.getPagos().forEach((pago) => {
          const tipo = pago.getTipo();
          if (!ventasPorMetodo[tipo]) {
            ventasPorMetodo[tipo] = { cantidad: 0, monto: 0 };
          }
          ventasPorMetodo[tipo].cantidad += 1;
          ventasPorMetodo[tipo].monto += pago.getMonto();
        });
      });

      // Convertir a porcentajes
      const ventasPorMetodoPago: Record<string, any> = {};
      Object.entries(ventasPorMetodo).forEach(([metodo, datos]) => {
        ventasPorMetodoPago[metodo] = {
          cantidad: datos.cantidad,
          monto: datos.monto,
          porcentaje: (datos.monto / estadisticas.totalVentas) * 100,
        };
      });

      return {
        fecha: reportDate.toISOString().split('T')[0],
        totalVentas: estadisticas.totalVentas,
        cantidadVentas: estadisticas.cantidadVentas,
        ticketPromedio: estadisticas.ticketPromedio,
        ventasMax: estadisticas.ventasMayoreMenor?.mayor?.getTotal() || 0,
        ventasMin: estadisticas.ventasMayoreMenor?.menor?.getTotal() || 0,
        ventasPorMetodoPago,
      };
    } catch (error: any) {
      console.error(
        `[ReporteService] Error generando resumen financiero: ${error.message}`,
      );
      throw new Error(
        `Error generando resumen financiero: ${error.message}`,
      );
    }
  }
}
