/**
 * @fileoverview Ejemplos de uso de VentaService
 * Flujos completos del Saga Pattern
 */

import { VentaService } from './VentaService';
import { IVentaRepository } from '@application/interfaces/IVentaRepository';
import { IInventoryProvider } from '@domain/ports/IInventoryProvider';
import { CreateVentaDTO } from '@application/dtos/CreateVentaDTO';
import { Usuario, RoleType, PermissionType } from '@domain/entities/Usuario';

/**
 * ============================================================================
 * EJEMPLO 1: Crear una venta simple (Saga Pattern completo)
 * ============================================================================
 */

/*
async function crearVentaSimple(
  ventaService: VentaService,
  ventaRepository: IVentaRepository,
  inventoryProvider: IInventoryProvider,
) {
  // Simular usuario autenticado
  const usuario = Usuario.crear(
    'UID-USER-123',
    'cajero@farmacia.com',
    'Juan Pérez',
    RoleType.CAJERO,
    [PermissionType.CREAR_VENTA, PermissionType.DESCONTAR_STOCK],
  );

  // DTO con venta simple
  const ventaDTO: CreateVentaDTO = {
    usuarioId: usuario.getId(),
    lineas: [
      {
        codigoProducto: '7501345678901',
        nombreProducto: 'Amoxicilina 500mg',
        cantidad: 2,
        precioUnitario: 15000,
        esControlado: false,
      },
    ],
    pagos: [
      {
        tipo: 'efectivo',
        monto: 35700, // (15000 * 2) * 1.19
      },
    ],
    ivaPercentaje: 19,
  };

  try {
    // Saga Pattern se ejecuta dentro de crearVenta()
    const venta = await ventaService.crearVenta(usuario, ventaDTO);
    console.log('✅ Venta creada:', venta.getId());
    return venta;
  } catch (error) {
    console.error('❌ Error creando venta:', error);
    throw error;
  }
}
*/

/**
 * ============================================================================
 * EJEMPLO 2: Venta con productos controlados (Auditoría incluida)
 * ============================================================================
 */

/*
async function crearVentaControlada(ventaService: VentaService) {
  const usuario = Usuario.crear(
    'UID-FARMACEUTICO-456',
    'farmaceutico@farmacia.com',
    'Dr. Carlos López',
    RoleType.FARMACEUTICO,
    [
      PermissionType.CREAR_VENTA,
      PermissionType.DESCONTAR_STOCK,
    ],
  );

  const ventaDTO: CreateVentaDTO = {
    usuarioId: usuario.getId(),
    lineas: [
      {
        codigoProducto: 'MED-CTRL-001',
        nombreProducto: 'Alprazolam 0.5mg',
        cantidad: 1,
        precioUnitario: 45000,
        esControlado: true, // ⚠️ Controlado
        lote: 'LOTE-2026-001',
      },
    ],
    pagos: [
      {
        tipo: 'efectivo',
        monto: 53550, // 45000 * 1.19
      },
    ],
    datosReceta: {
      ciMedico: '12345678',
      nombreMedico: 'Dr. Carlos López',
      fechaReceta: '2026-03-13T10:30:00Z',
    },
  };

  try {
    const venta = await ventaService.crearVenta(usuario, ventaDTO);
    // Automáticamente se registra en auditoria_recetas
    console.log('✅ Venta con auditoría creada:', venta.getId());
    return venta;
  } catch (error) {
    console.error('❌ Error:', error);
  }
}
*/

/**
 * ============================================================================
 * EJEMPLO 3: Manejar errores del Saga Pattern
 * ============================================================================
 */

/*
import {
  VentaService,
  StockInsuficienteError,
  CompensacionFallidaError,
  VentaServiceError,
} from './VentaService';

async function crearVentaConErrorHandling(
  ventaService: VentaService,
) {
  try {
    const venta = await ventaService.crearVenta(usuario, ventaDTO);
    return venta;
  } catch (error) {
    if (error instanceof StockInsuficienteError) {
      // ❌ PASO 2 FALLÓ: Stock insuficiente
      console.error('Stock insuficiente:', error.detalles);
      // → No se persistió nada, sin necesidad de compensación
      return res.status(400).json({
        error: 'Stock insuficiente',
        productos: error.detalles,
      });
    }

    if (error instanceof CompensacionFallidaError) {
      // ❌ CRÍTICO: Persistencia falló Y compensación falló
      console.error('FALLO CRÍTICO:', error.ventaId);
      // → REQUIERE INTERVENCIÓN MANUAL
      return res.status(500).json({
        error: 'Error crítico. Contactar soporte.',
        ventaId: error.ventaId,
        code: error.code,
      });
    }

    if (error instanceof VentaServiceError) {
      // ❌ Error general en servicio
      console.error('Error de servicio:', error.code);
      return res.status(400).json({
        error: error.message,
        code: error.code,
      });
    }

    // Error desconocido
    console.error('Error inesperado:', error);
    return res.status(500).json({ error: 'Error inesperado' });
  }
}
*/

/**
 * ============================================================================
 * EJEMPLO 4: Consultar ventas del usuario (HU-35)
 * ============================================================================
 */

/*
async function consultarVentasUsuario(
  ventaService: VentaService,
  usuarioId: string,
) {
  try {
    const ventas = await ventaService.obtenerVentasDelUsuario(usuarioId, {
      limit: 50,
      offset: 0,
    });

    console.log(`Ventas del usuario ${usuarioId}:`);
    ventas.forEach((v) => {
      console.log(`- Folio: ${v.getId()}, Total: ${v.getTotal()}, Fecha: ${v.getFechaVenta()}`);
    });

    return ventas;
  } catch (error) {
    console.error('Error consultando ventas:', error);
  }
}
*/

/**
 * ============================================================================
 * EJEMPLO 5: Anular una venta (HU-35)
 * ============================================================================
 */

/*
async function anularVentaEjemplo(
  ventaService: VentaService,
  ventaId: string,
  usuarioId: string,
) {
  try {
    const ventaAnulada = await ventaService.anularVenta(
      ventaId,
      'Cambio de opinión del cliente',
      usuarioId,
    );

    console.log(`✅ Venta ${ventaId} anulada exitosamente`);
    return ventaAnulada;
  } catch (error) {
    console.error('❌ Error anulando venta:', error);
  }
}
*/

/**
 * ============================================================================
 * EJEMPLO 6: Obtener estadísticas diarias (HU-39)
 * ============================================================================
 */

/*
async function obtenerReporteDiario(ventaService: VentaService) {
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);

  const mañana = new Date(hoy);
  mañana.setDate(mañana.getDate() + 1);

  try {
    const estadisticas = await ventaService.obtenerEstadisticas(hoy, mañana);

    console.log('📊 Reporte del día:');
    console.log(`  Total ventas: ${estadisticas.totalVentas}`);
    console.log(`  Cantidad de tickets: ${estadisticas.cantidadVentas}`);
    console.log(`  Ticket promedio: ${estadisticas.ticketPromedio}`);
    console.log(`  Mayor venta: ${estadisticas.ventasMayoreMenor.mayor.getTotal()}`);
    console.log(`  Menor venta: ${estadisticas.ventasMayoreMenor.menor.getTotal()}`);

    return estadisticas;
  } catch (error) {
    console.error('Error obteniendo estadísticas:', error);
  }
}
*/

/**
 * ============================================================================
 * DIAGRAMA DEL SAGA PATTERN IMPL EMENTADO
 * ============================================================================
 *
 * POST /api/ventas/procesar { CreateVentaDTO }
 *              ↓
 *        VentaService.crearVenta()
 *              ↓
 *    ┌─────────┴─────────┐
 *    │                   │
 * PASO 1             TRANSACCIÓN DISTRIBUIDA
 * Validar DTO        ┌────────────────────────────────┐
 *    │               │ SAGA START                     │
 *    ↓               │ ┌──────────────────────────┐   │
 * Crear Venta        │ │ Step 1: Descontar Stock │   │
 * Entity             │ │ Python: POST /inventario│   │
 *    │               │ │         /descontar      │   │
 *    │               │ └──────────────────────────┘   │
 *    │               │ ✅ Success → Continuar         │
 *    │               │ ❌ Falla → Retornar error      │
 *    │               │           (sin compensar)     │
 *    │               │                                │
 *    │               │ ┌──────────────────────────┐   │
 *    │               │ │ Step 2: Persistir Venta  │   │
 *    │               │ │ Firestore: tickets_ventas│   │
 *    │               │ └──────────────────────────┘   │
 *    │               │ ✅ Success → Continuar         │
 *    │               │ ❌ Falla → COMPENSAR:          │
 *    │               │    Python: POST /inventario    │
 *    │               │            /compensar          │
 *    │               │    ✅ Compensacion ok          │
 *    │               │    ❌ Compensacion falla       │
 *    │               │        → CRÍTICO (intervenir)  │
 *    │               │                                │
 *    │               │ ┌──────────────────────────┐   │
 *    │               │ │ Step 3: Auditoría (Si   │   │
 *    │               │ │ hay controlados)         │   │
 *    │               │ │ Firestore:              │   │
 *    │               │ │ auditoria_recetas       │   │
 *    │               │ └──────────────────────────┘   │
 *    │               │ (Error no-crítico)            │
 *    │               │                                │
 *    │               │ SAGA END ✅                    │
 *    │               └────────────────────────────────┘
 *    ↓
 * Retornar Venta
 *
 */

export const VENTA_SERVICE_EXAMPLES = {
  // Ejemplos documentados arriba
};
