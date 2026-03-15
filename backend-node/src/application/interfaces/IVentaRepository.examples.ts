/**
 * @fileoverview Ejemplos de uso de IVentaRepository
 * Casos prácticos de cómo se utiliza el repositorio
 */

import { IVentaRepository, IFiltrosVenta } from './IVentaRepository';

/**
 * ============================================================================
 * EJEMPLO 1: Crear una venta (Parte del Saga Pattern)
 * ============================================================================
 */

/*
async function crearVenta(
  ventaService: VentaService,
  ventaDTO: CreateVentaDTO,
) {
  // 1. Validar DTO
  const ventaValidada = validarCreateVentaDTO(ventaDTO);

  // 2. Crear entidad de dominio
  const venta = Venta.crear(
    generateUUID(), // Generar folio único
    ventaValidada.usuarioId,
    // ... líneas, pagos, datosReceta, iva
  );

  // 3. Persistir en Firestore (colección: tickets_ventas)
  const ventaCreada = await ventaRepository.crear(venta);

  // 4. Si hay productos controlados → registrar auditoría
  if (venta.getTieneProductosControlados()) {
    await ventaRepository.registrarRecetaControlada(
      ventaCreada.getId(),
      venta.getDatosReceta()!,
      // ... productos controlados
    );
  }

  return ventaCreada;
}
*/

/**
 * ============================================================================
 * EJEMPLO 2: Consultar ventas de un usuario (HU-35: Por turno/UID)
 * ============================================================================
 */

/*
async function consultarVentasDelUsuario(
  usuarioId: string,
  ventaRepository: IVentaRepository,
) {
  // Obtener todas las ventas del usuario
  const ventas = await ventaRepository.obtenerPorUsuario(usuarioId, {
    limit: 50,
    offset: 0,
  });

  // Mostrar en dashboard
  return {
    totalVentas: ventas.length,
    ventasHoy: ventas.filter(
      (v) => v.getFechaVenta().toDateString() === new Date().toDateString(),
    ),
    ventasRecientes: ventas.slice(0, 10),
  };
}
*/

/**
 * ============================================================================
 * EJEMPLO 3: Anular una venta (HU-35: Anulación de tickets)
 * ============================================================================
 */

/*
async function anularVenta(
  ventaId: string,
  motivoAnulacion: string,
  usuarioId: string,
  ventaRepository: IVentaRepository,
  inventoryProvider: IInventoryProvider,
) {
  // 1. Anular en Firestore
  const ventaAnulada = await ventaRepository.anular(
    ventaId,
    motivoAnulacion,
    usuarioId,
  );

  // 2. Reintegrar stock en Python
  const lineasDescontar = ventaAnulada
    .getLineas()
    .map((l) => ({
      codigoProducto: l.getCodigoProducto(),
      cantidad: l.getCantidad(),
      lote: l.getLote(),
    }));

  await inventoryProvider.compensar(ventaId, lineasDescontar);

  return ventaAnulada;
}
*/

/**
 * ============================================================================
 * EJEMPLO 4: Reportes administrativos (HU-35, HU-39)
 * ============================================================================
 */

/*
async function obtenerResumenDiario(
  fecha: Date,
  ventaRepository: IVentaRepository,
) {
  // 1. Obtener estadísticas del día
  const estadisticas = await ventaRepository.obtenerEstadisticas(
    new Date(fecha.toDateString()),
    new Date(fecha.toDateString() + ' 23:59:59'),
  );

  // 2. Obtener todas las ventas del período
  const resultado = await ventaRepository.listar({
    fechaInicio: new Date(fecha.toDateString()),
    fechaFin: new Date(fecha.toDateString() + ' 23:59:59'),
    estado: 'procesada',
    limit: 1000,
  });

  return {
    fecha: fecha.toDateString(),
    estadisticas,
    ventasProcesadas: resultado.ventas,
    totalRegistros: resultado.total,
  };
}
*/

/**
 * ============================================================================
 * EJEMPLO 5: Auditoría de productos controlados (HU-30, HU-39)
 * ============================================================================
 */

/*
async function obtenerReporteSanitario(
  ventaRepository: IVentaRepository,
) {
  // Obtener auditoría de productos controlados (últimos 30 días)
  const hace30Dias = new Date();
  hace30Dias.setDate(hace30Dias.getDate() - 30);

  const auditoria = await ventaRepository.obtenerAuditoriaRecetas({
    fechaInicio: hace30Dias,
    fechaFin: new Date(),
    limit: 500,
  });

  return {
    periodo: `${hace30Dias.toDateString()} - ${new Date().toDateString()}`,
    registrosControlados: auditoria.length,
    productosControlados: auditoria,
    resumenPorMedico: agruparPorMedico(auditoria),
  };
}
*/

/**
 * ============================================================================
 * EJEMPLO 6: Trazabilidad de lotes FEFO (HU-31, HU-40)
 * ============================================================================
 */

/*
async function rastrearLote(
  lote: string,
  ventaRepository: IVentaRepository,
) {
  // Encontrar todas las ventas donde se despachó este lote
  const ventasConLote = await ventaRepository.obtenerPorLote(lote);

  return {
    lote,
    ventasDespachos: ventasConLote.map((v) => ({
      ventaId: v.getId(),
      fecha: v.getFechaVenta(),
      cantidad: v.getLineas().find((l) => l.getLote() === lote)?.getCantidad(),
      usuario: v.getUsuarioId(),
    })),
    totalDespachadoDelLote: ventasConLote.reduce(
      (sum, v) =>
        sum +
        (v.getLineas().find((l) => l.getLote() === lote)?.getCantidad() || 0),
      0,
    ),
  };
}
*/

/**
 * ============================================================================
 * MÉTODOS DE APOYO
 * ============================================================================
 */

/**
 * Agrupar auditoría de recetas por médico (para reportes)
 */
function agruparPorMedico(auditoria: any[]) {
  const agrupado: Record<string, any> = {};

  auditoria.forEach((registro) => {
    const ci = registro.datosReceta.ciMedico;
    if (!agrupado[ci]) {
      agrupado[ci] = {
        ciMedico: ci,
        nombreMedico: registro.datosReceta.nombreMedico,
        totalProductos: 0,
        registros: [],
      };
    }
    agrupado[ci].totalProductos += registro.productosControlados.length;
    agrupado[ci].registros.push(registro);
  });

  return Object.values(agrupado);
}

/**
 * ============================================================================
 * CASOS DE ERROR (Validaciones)
 * ============================================================================
 */

/*
// ❌ ERROR: Intentar anular una venta que no existe
try {
  await ventaRepository.anular('VENTA_INEXISTENTE', 'Motivo', 'usuario123');
} catch (error) {
  // NotFoundError: "Venta VENTA_INEXISTENTE no encontrada"
}

// ❌ ERROR: Obtener venta inexistente
try {
  await ventaRepository.obtenerPorId('VENTA_NO_EXISTE');
} catch (error) {
  // NotFoundError: "Venta VENTA_NO_EXISTE no encontrada"
}

// ❌ ERROR: Crear venta sin permiso (manejo en Controller, no en Repo)
// El repositorio NO valida permisos, solo persistencia
*/

export const VENTA_REPOSITORY_EXAMPLES = {
  // Métodos comunes documentados arriba
};
