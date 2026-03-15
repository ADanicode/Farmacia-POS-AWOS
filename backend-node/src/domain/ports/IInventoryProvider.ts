/**
 * @fileoverview Puerto IInventoryProvider - Interfaz de la Capa de Dominio
 * Define el contrato para la comunicación con el servicio de Inventario de Python (Karel)
 * Esta es una interfaz de salida (salienda) - Hexagonal Architecture
 * La implementación real estará en infrastructure/external
 */

import { LineaVenta } from '../entities/Venta';

/**
 * Interface para una línea de venta a descontar del inventario
 */
export interface ILineaDescontar {
  codigoProducto: string;
  cantidad: number;
  lote?: string;
}

/**
 * Interface para la respuesta de descuento exitoso
 */
export interface IDescontarResponse {
  exitoso: boolean;
  mensaje: string;
  detalles: {
    lineas: Array<{
      codigoProducto: string;
      cantidadDescontada: number;
      inventarioAnterior: number;
      inventarioNuevo: number;
      loteUtilizado?: string;
    }>;
  };
}

/**
 * Interface para la compensación (rollback) en caso de fallo
 */
export interface ICompensarRequest {
  ventaId: string;
  lineas: ILineaDescontar[];
}

/**
 * Interface para la respuesta de compensación
 */
export interface ICompensarResponse {
  exitoso: boolean;
  mensaje: string;
  detalles: {
    lineas: Array<{
      codigoProducto: string;
      cantidadReintegrada: number;
    }>;
  };
}

/**
 * Puerto de Salida: IInventoryProvider
 * Define el contrato para la comunicación con el servicio de Inventario
 * Implementaciones concretas:
 *   - HttpInventoryProvider (llamadas HTTP vía Axios a FastAPI de Karel)
 *   - MockInventoryProvider (para tests)
 */
export interface IInventoryProvider {
  /**
   * Descuenta stock del inventario (HU-28, HU-29)
   * Implementa lógica FEFO en el backend de Python
   * Falla si no hay stock suficiente
   *
   * @param ventaId - ID de la venta (para trazabilidad)
   * @param lineas - Array de líneas a descontar
   * @returns Promise con detalles del descuento realizado
   * @throws {Error} Si falla el descuento (stock insuficiente, validación, etc)
   */
  descontarStock(
    ventaId: string,
    lineas: ILineaDescontar[],
  ): Promise<IDescontarResponse>;

  /**
   * Compensa el descuento realizado (rollback)
   * Se llama si la persistencia en Firestore falla (Saga Pattern)
   * Reintegra las cantidades descontadas al inventario
   *
   * @param ventaId - ID de la venta
   * @param lineas - Array de líneas a reintegrar
   * @returns Promise con detalles de la compensación
   * @throws {Error} Si falla la compensación
   */
  compensar(
    ventaId: string,
    lineas: ILineaDescontar[],
  ): Promise<ICompensarResponse>;

  /**
   * Valida disponibilidad de un producto específico (opcional)
   * Útil para chequeos previos antes de procesar venta
   *
   * @param codigoProducto - Código a validar
   * @param cantidad - Cantidad requerida
   * @returns Promise<boolean> true si hay stock disponible
   */
  validarDisponibilidad?(
    codigoProducto: string,
    cantidad: number,
  ): Promise<boolean>;
}

/**
 * Mapper para convertir LineaVenta (entity) a ILineaDescontar (DTO)
 */
export class MapperLineaDescontar {
  public static fromLineaVenta(linea: LineaVenta): ILineaDescontar {
    return {
      codigoProducto: linea.getCodigoProducto(),
      cantidad: linea.getCantidad(),
      lote: linea.getLote(),
    };
  }

  public static fromLineasVenta(lineas: LineaVenta[]): ILineaDescontar[] {
    return lineas.map((l) => this.fromLineaVenta(l));
  }
}
