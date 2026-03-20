/**
 * @fileoverview DTOs para el módulo de Ventas
 * Validación exhaustiva de datos de entrada con Zod
 */

import { z } from 'zod';
import { TipoPago } from '@domain/entities/Venta';

/**
 * Schema para validar un pago individual (HU-27: Pago Mixto)
 * Soporta efectivo, tarjeta, o combinaciones
 */
export const PagoSchema = z.object({
  tipo: z.enum([TipoPago.EFECTIVO, TipoPago.TARJETA], {
    errorMap: () => ({
      message: 'Tipo de pago debe ser "efectivo" o "tarjeta"',
    }),
  }).describe('Tipo de pago'),
  monto: z
    .number()
    .positive('Monto debe ser mayor a 0')
    .describe('Monto pagado'),
  referencia: z
    .string()
    .optional()
    .describe('Referencia de la transacción (ej. número de recibo)'),
});

export type PagoDTO = z.infer<typeof PagoSchema>;

/**
 * Schema para datos de receta médica (HU-22, HU-23: Productos controlados)
 * Obligatorio si la venta incluye productos controlados
 */
export const DatosRecetaSchema = z.object({
  ciMedico: z
    .string()
    .min(5, 'CI del médico debe tener mínimo 5 caracteres')
    .describe('Cédula de identidad del médico prescriptor'),
  nombreMedico: z
    .string()
    .min(2, 'Nombre del médico debe tener mínimo 2 caracteres')
    .max(100, 'Nombre del médico no puede exceder 100 caracteres')
    .describe('Nombre completo del médico prescriptor'),
  fechaReceta: z
    .string()
    .datetime()
    .describe('Fecha/hora de emisión de la receta en ISO 8601'),
});

export type DatosRecetaDTO = z.infer<typeof DatosRecetaSchema>;

/**
 * Schema para una línea de venta (producto + cantidad)
 * HU-17: Carrito, HU-23: Productos controlados, HU-28: FEFO
 */
export const LineaVentaSchema = z.object({
  codigoProducto: z
    .string()
    .min(1, 'Código de producto requerido')
    .describe('Código de barras del producto'),
  nombreProducto: z
    .string()
    .min(1, 'Nombre de producto requerido')
    .describe('Nombre del producto'),
  cantidad: z
    .number()
    .int()
    .positive('Cantidad debe ser mayor a 0')
    .describe('Cantidad solicitada'),
  precioUnitario: z
    .number()
    .positive('Precio unitario debe ser mayor a 0')
    .describe('Precio sin IVA por unidad'),
  esControlado: z
    .boolean()
    .default(false)
    .describe('¿Es producto controlado (requiere receta)?'),
  lote: z
    .string()
    .optional()
    .describe('Lote del medicamento (para trazabilidad FEFO)'),
});

export type LineaVentaDTO = z.infer<typeof LineaVentaSchema>;

/**
 * Schema principal para crear una venta
 * HU-28, HU-29: Orquestación Saga Pattern
 * Validaciones:
 * - Al menos una línea
 * - Al menos un pago
 * - Suma de pagos = total calculado
 * - Si hay controlados → DatosReceta obligatoria
 */
export const CreateVentaSchema = z
  .object({
    usuarioId: z
      .string()
      .min(1, 'UID del usuario requerido')
      .describe('UID del usuario que realiza la venta'),
    lineas: z
      .array(LineaVentaSchema)
      .min(1, 'La venta debe tener al menos una línea')
      .describe('Array de productos en la venta'),
    pagos: z
      .array(PagoSchema)
      .min(1, 'La venta debe tener al menos un método de pago')
      .describe('Array de pagos (soporta Pago Mixto)'),
    ivaPercentaje: z
      .number()
      .min(0, 'IVA no puede ser negativo')
      .max(100, 'IVA no puede ser mayor a 100')
      .default(19)
      .describe('Porcentaje de IVA a aplicar'),
    datosReceta: DatosRecetaSchema.optional().describe(
      'Datos del médico (OBLIGATORIO si hay productos controlados)',
    ),
  })
  .refine(
    (data: any) => {
      const tieneControlados = (data.lineas as LineaVentaDTO[]).some(
        (l) => l.esControlado,
      );
      if (tieneControlados && !data.datosReceta) {
        return false;
      }
      return true;
    },
    {
      message:
        'Datos de receta médica son OBLIGATORIOS si hay productos controlados',
      path: ['datosReceta'],
    },
  )
  .refine(
    (data: any) => {
      const lineas = data.lineas as LineaVentaDTO[];
      const pagos = data.pagos as PagoDTO[];
      const ivaPercentaje = (data.ivaPercentaje as number) || 16;

      const subtotal = lineas.reduce(
        (sum: number, linea: LineaVentaDTO) =>
          sum + linea.cantidad * linea.precioUnitario,
        0,
      );
      const iva = subtotal * (ivaPercentaje / 100);
      const totalEsperado = subtotal + iva;

      const totalPagos = pagos.reduce((sum: number, pago: PagoDTO) => sum + pago.monto, 0);

      return Math.abs(totalPagos - totalEsperado) < 0.01;
    },
    {
      message:
        'La suma de pagos debe coincidir exactamente con el total de la venta (subtotal + IVA)',
      path: ['pagos'],
    },
  );

export type CreateVentaDTO = z.infer<typeof CreateVentaSchema>;

/**
 * Valida un CreateVentaDTO
 * @param data - Objeto a validar
 * @returns CreateVentaDTO validado
 * @throws {ZodError} Si la validación falla
 */
export function validarCreateVentaDTO(data: unknown): CreateVentaDTO {
  return CreateVentaSchema.parse(data);
}

/**
 * Validación segura de CreateVentaDTO (sin lanzar excepciones)
 * @param data - Objeto a validar
 * @returns { success: true, data } | { success: false, errors }
 */
export function validarCreateVentaDTOSafe(data: unknown) {
  const resultado = CreateVentaSchema.safeParse(data);
  if (resultado.success) {
    return {
      success: true as const,
      data: resultado.data,
    };
  }
  return {
    success: false as const,
    errors: resultado.error.flatten().fieldErrors,
  };
}

/**
 * Calcula el total de una venta para validaciones
 * @param lineas - Array de líneas de venta
 * @param ivaPercentaje - Porcentaje de IVA
 * @returns { subtotal, iva, total }
 */
export function calcularTotalVenta(
  lineas: LineaVentaDTO[],
  ivaPercentaje: number = 19,
) {
  const subtotal = lineas.reduce(
    (sum, linea) => sum + linea.cantidad * linea.precioUnitario,
    0,
  );
  const iva = subtotal * (ivaPercentaje / 100);
  const total = subtotal + iva;

  return {
    subtotal: Math.round(subtotal * 100) / 100,
    iva: Math.round(iva * 100) / 100,
    total: Math.round(total * 100) / 100,
  };
}
