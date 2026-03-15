/**
 * @fileoverview Ejemplos y documentación del CreateVentaDTO
 * Casos de uso y validaciones del schema Zod
 */

import {
  CreateVentaDTO,
  calcularTotalVenta,
  validarCreateVentaDTOSafe,
} from './CreateVentaDTO';
import { TipoPago } from '@domain/entities/Venta';

/**
 * ============================================================================
 * EJEMPLO 1: Venta Simple (Un Pago en Efectivo - HU-25)
 * ============================================================================
 */

export const VENTA_SIMPLE_EFECTIVO: CreateVentaDTO = {
  usuarioId: 'KfB8xA9p2L0Wq1Rs2Tt3Uu4Vv5',
  lineas: [
    {
      codigoProducto: '7501345678901',
      nombreProducto: 'Amoxicilina 500mg',
      cantidad: 2,
      precioUnitario: 15000,
      esControlado: false,
      lote: 'LOT001',
    },
    {
      codigoProducto: '7501345678902',
      nombreProducto: 'Ibupirac 400mg',
      cantidad: 1,
      precioUnitario: 12000,
      esControlado: false,
    },
  ],
  pagos: [
    {
      tipo: TipoPago.EFECTIVO,
      monto: 52800,
      referencia: 'TALONARIO-2026-0001',
    },
  ],
  ivaPercentaje: 19,
};

/**
 * ============================================================================
 * EJEMPLO 2: Venta con Pago Mixto (HU-27)
 * ============================================================================
 */

export const VENTA_PAGO_MIXTO: CreateVentaDTO = {
  usuarioId: 'KfB8xA9p2L0Wq1Rs2Tt3Uu4Vv5',
  lineas: [
    {
      codigoProducto: '7501345678903',
      nombreProducto: 'Vitamina C 1000mg',
      cantidad: 3,
      precioUnitario: 25000,
      esControlado: false,
    },
  ],
  pagos: [
    {
      tipo: TipoPago.EFECTIVO,
      monto: 30000,
      referencia: 'TALONARIO-2026-0002',
    },
    {
      tipo: TipoPago.TARJETA,
      monto: 59250,
      referencia: 'VISA-LAST4-***5678',
    },
  ],
  ivaPercentaje: 19,
};

/**
 * ============================================================================
 * EJEMPLO 3: Venta con Productos Controlados (HU-22, HU-23)
 * ============================================================================
 * OBLIGATORIO incluir datosReceta si hay productos controlados
 */

export const VENTA_CONTROLADA: CreateVentaDTO = {
  usuarioId: 'KfB8xA9p2L0Wq1Rs2Tt3Uu4Vv5',
  lineas: [
    {
      codigoProducto: '7501345678904',
      nombreProducto: 'Alprazolam 0.5mg',
      cantidad: 1,
      precioUnitario: 45000,
      esControlado: true,
      lote: 'CTRL-2026-001',
    },
  ],
  pagos: [
    {
      tipo: TipoPago.EFECTIVO,
      monto: 53550,
    },
  ],
  datosReceta: {
    ciMedico: '12345678',
    nombreMedico: 'Dr. Juan Pérez González',
    fechaReceta: '2026-03-13T10:30:00Z',
  },
  ivaPercentaje: 19,
};

/**
 * ============================================================================
 * VALIDACIONES QUE REALIZA EL SCHEMA
 * ============================================================================
 */

/*
 * 1. VALIDACIÓN DE LÍNEAS
 *    - Al menos 1 línea: ❌ No se puede crear venta sin productos
 *    - codigoProducto: No puede estar vacío
 *    - cantidad: Debe ser > 0, entero
 *    - precioUnitario: Debe ser > 0
 *
 * 2. VALIDACIÓN DE PAGOS
 *    - Al menos 1 pago: ❌ No se puede crear venta sin pago
 *    - tipo: Debe ser "efectivo" o "tarjeta"
 *    - monto: Debe ser > 0
 *
 * 3. VALIDACIÓN DE PRODUCTOS CONTROLADOS
 *    - Si esControlado === true:
 *      └─ datosReceta es OBLIGATORIO
 *      └─ ciMedico: Mínimo 5 caracteres
 *      └─ nombreMedico: Mínimo 2, máximo 100 caracteres
 *      └─ fechaReceta: Formato ISO 8601
 *
 * 4. VALIDACIÓN DE TOTALES (Crítica)
 *    - Subtotal = SUM(cantidad * precioUnitario)
 *    - IVA = subtotal * (ivaPercentaje / 100)
 *    - Total = subtotal + iva
 *    - SUM(pagos.monto) === Total ±0.01
 *      └─ ❌ Si no coinciden → RECHAZA LA VENTA
 *
 * 5. VALIDACIÓN DE PAGO MIXTO
 *    - Múltiples pagos permitidos
 *    - La suma total debe ser exacta
 *    - Cada pago es independiente
 */

/**
 * ============================================================================
 * ERRORES ESPERADOS (Ejemplos de rechazo)
 * ============================================================================
 */

// ❌ ERROR: Sin líneas
const VENTA_INVALIDA_1 = {
  usuarioId: 'user123',
  lineas: [], // ❌ Debe tener al menos 1
  pagos: [{ tipo: 'efectivo', monto: 1000 }],
};
// Error: "La venta debe tener al menos una línea"

// ❌ ERROR: Sin pagos
const VENTA_INVALIDA_2 = {
  usuarioId: 'user123',
  lineas: [{ codigoProducto: 'XXX', nombreProducto: 'Producto', cantidad: 1, precioUnitario: 100 }],
  pagos: [], // ❌ Debe tener al menos 1
};
// Error: "La venta debe tener al menos un método de pago"

// ❌ ERROR: Totales no coinciden
const VENTA_INVALIDA_3 = {
  usuarioId: 'user123',
  lineas: [{ codigoProducto: 'XXX', nombreProducto: 'Producto', cantidad: 1, precioUnitario: 100 }],
  pagos: [{ tipo: 'efectivo', monto: 50 }], // ❌ Debe ser 119 (100 * 1.19)
};
// Error: "La suma de pagos debe coincidir exactamente con el total de la venta"

// ❌ ERROR: Productos controlados sin receta
const VENTA_INVALIDA_4 = {
  usuarioId: 'user123',
  lineas: [
    {
      codigoProducto: 'XXX',
      nombreProducto: 'Medicamento Controlado',
      cantidad: 1,
      precioUnitario: 100,
      esControlado: true, // ⚠️ Controlado
      // datosReceta falta → ❌ OBLIGATORIO
    },
  ],
  pagos: [{ tipo: 'efectivo', monto: 119 }],
};
// Error: "Datos de receta médica son OBLIGATORIOS si hay productos controlados"

/**
 * ============================================================================
 * CÓMO USAR EN CONTROLERS
 * ============================================================================
 */

// Opción 1: Validación que lanza excepciones (para try-catch)
/*
try {
  const ventaDTO = validarCreateVentaDTO(req.body);
  const venta = await ventaService.crearVenta(ventaDTO);
  res.json(venta);
} catch (error) {
  if (error instanceof ZodError) {
    res.status(400).json({ error: error.flatten().fieldErrors });
  }
}
*/

// Opción 2: Validación segura (sin excepciones)
/*
const resultado = validarCreateVentaDTOSafe(req.body);
if (!resultado.success) {
  return res.status(400).json({ errors: resultado.errors });
}
const venta = await ventaService.crearVenta(resultado.data);
res.json(venta);
*/

/**
 * ============================================================================
 * FUNCIÓN HELPER: Calcular totales
 * ============================================================================
 */

// Ejemplo de uso
/*
const ventaDTO = { ... };
const totales = calcularTotalVenta(ventaDTO.lineas, ventaDTO.ivaPercentaje);
console.log(totales);
// { subtotal: 42000, iva: 7980, total: 49980 }
*/

export const VENTA_EXAMPLES = {
  SIMPLE_EFECTIVO: VENTA_SIMPLE_EFECTIVO,
  PAGO_MIXTO: VENTA_PAGO_MIXTO,
  CONTROLADA: VENTA_CONTROLADA,
};
