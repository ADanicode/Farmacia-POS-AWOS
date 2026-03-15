/**
 * @fileoverview HttpInventoryProvider - Adaptador HTTP para comunicación con backend Python (Karel)
 * Implementa IInventoryProvider para descontar stock y ejecutar compensaciones
 * Parte crítica del Saga Pattern
 */

import axios, { AxiosInstance } from 'axios';
import {
  IInventoryProvider,
  ILineaDescontar,
  IDescontarResponse,
  ICompensarResponse,
} from '@domain/ports/IInventoryProvider';

/**
 * HttpInventoryProvider - Adaptador para comunicar con backend Python
 * Responsabilidades:
 * - Descontar stock en SAGA STEP 1 (POST /inventario/descontar)
 * - Ejecutar compensación en SAGA STEP 2 fallido (POST /inventario/compensar)
 * - Validar disponibilidad (opcional, pre-check)
 *
 * La URL base del backend Python se configura via env var PYTHON_INVENTORY_URL
 * Ejemplo: http://localhost:5000
 */
export class HttpInventoryProvider implements IInventoryProvider {
  private readonly client: AxiosInstance;
  private readonly baseURL: string;

  /**
   * Constructor con configuración de cliente HTTP
   * @param baseURL - URL base del backend Python (ej: http://localhost:5000)
   * @param timeout - Timeout en ms para requests (default: 10000)
   */
  constructor(baseURL: string = process.env.PYTHON_INVENTORY_URL || 'http://localhost:5000', timeout: number = 10000) {
    this.baseURL = baseURL;
    this.client = axios.create({
      baseURL: this.baseURL,
      timeout,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    console.log(`[HttpInventoryProvider] Inicializado con baseURL: ${this.baseURL}`);
  }

  /**
   * Descuenta stock en backend Python (SAGA STEP 1)
   * POST /api/inventario/descontar
   *
   * @param ventaId - ID único de la venta (folio)
   * @param lineas - Array de líneas a descontar con código, cantidad, lote FEFO
   * @returns Respuesta con detalles del descuento
   * @throws Error si stock insuficiente o error de comunicación
   */
  public async descontarStock(
    ventaId: string,
    lineas: ILineaDescontar[],
  ): Promise<IDescontarResponse> {
    try {
      console.log(
        `[HttpInventoryProvider] Enviando solicitud de descuento para venta ${ventaId}`,
      );
      console.log(`[HttpInventoryProvider] Líneas a descontar: ${JSON.stringify(lineas)}`);

      const response = await this.client.post('/api/inventario/descontar', {
        ventaId,
        lineas,
      });

      console.log(
        `[HttpInventoryProvider] Respuesta exitosa: ${JSON.stringify(response.data)}`,
      );

      return response.data as IDescontarResponse;
    } catch (error: any) {
      const message = error.response?.data?.message || error.message || 'Error desconocido';

      console.error(
        `[HttpInventoryProvider] Error al descontar stock: ${message}`,
      );

      if (error.response?.status === 400) {
        // Stock insuficiente u error de validación
        throw new Error(`stock insuficiente: ${message}`);
      }

      throw new Error(
        `Error comunicando con backend Python (inventario): ${message}`,
      );
    }
  }

  /**
   * Compensa (reintegra) stock en backend Python (SAGA STEP 2 fallido)
   * POST /api/inventario/compensar
   *
   * Se ejecuta si la persistencia en Firestore falla en VentaService
   * para mantener consistency entre Node.js y Python
   *
   * @param ventaId - ID de la venta descuento original
   * @param lineas - Array de líneas a compensar (mismo formato que descontar)
   * @returns Respuesta exitosa de compensación
   * @throws Error si compensación falla (CRÍTICO - requiere intervención manual)
   */
  public async compensar(
    ventaId: string,
    lineas: ILineaDescontar[],
  ): Promise<ICompensarResponse> {
    try {
      console.log(
        `[HttpInventoryProvider] Iniciando compensación para venta ${ventaId}`,
      );
      console.log(`[HttpInventoryProvider] Líneas a compensar: ${JSON.stringify(lineas)}`);

      const response = await this.client.post('/api/inventario/compensar', {
        ventaId,
        lineas,
      });

      console.log(
        `[HttpInventoryProvider] Compensación exitosa: ${JSON.stringify(response.data)}`,
      );

      return response.data as ICompensarResponse;
    } catch (error: any) {
      const message = error.response?.data?.message || error.message || 'Error desconocido';

      console.error(
        `[HttpInventoryProvider] FALLO CRÍTICO en compensación: ${message}`,
      );

      throw new Error(
        `Fallo crítico en compensación de inventario: ${message}`,
      );
    }
  }

  /**
   * Valida disponibilidad de productos (OPCIONAL)
   * GET /api/inventario/validar?codigoProducto=X&cantidad=Y
   *
   * Útil para pre-checks antes de iniciar el Saga Pattern
   * No es crítico para el flujo, solo para mejorar UX
   *
   * @param codigoProducto - Código del producto
   * @param cantidad - Cantidad a validar
   * @returns true si disponible, false si no
   */
  public async validarDisponibilidad(
    codigoProducto: string,
    cantidad: number,
  ): Promise<boolean> {
    try {
      console.log(
        `[HttpInventoryProvider] Validando disponibilidad: ${codigoProducto} x${cantidad}`,
      );

      const response = await this.client.get('/api/inventario/validar', {
        params: {
          codigoProducto,
          cantidad,
        },
      });

      const disponible = response.data?.disponible ?? false;
      console.log(
        `[HttpInventoryProvider] Disponibilidad de ${codigoProducto}: ${disponible}`,
      );

      return disponible;
    } catch (error: any) {
      console.error(
        `[HttpInventoryProvider] Error validando disponibilidad: ${error.message}`,
      );
      return false;
    }
  }
}
