import axios, { AxiosInstance } from 'axios';
import {
  IInventoryProvider,
  ILineaDescontar,
  IDescontarResponse,
  ICompensarResponse,
  IDatosRecetaDescuento,
} from '@domain/ports/IInventoryProvider';

export class HttpInventoryProvider implements IInventoryProvider {
  private readonly client: AxiosInstance;
  private readonly baseURL: string;

  constructor(
    baseURL: string = process.env.PYTHON_INVENTORY_URL || 'http://localhost:8000',
    timeout: number = 10000,
  ) {
    this.baseURL = baseURL;
    this.client = axios.create({
      baseURL: this.baseURL,
      timeout,
      headers: { 'Content-Type': 'application/json' },
    });
    console.log(`[HttpInventoryProvider] Inicializado con baseURL: ${this.baseURL}`);
  }

  public async descontarStock(
    ventaId: string,
    lineas: ILineaDescontar[],
    datosReceta?: IDatosRecetaDescuento,
  ): Promise<IDescontarResponse> {
    try {
      console.log(`[HttpInventoryProvider] Descuentando stock para venta ${ventaId}`);
      const response = await this.client.post('/api/v1/inventario/descontar', {
        ventaId,
        lineas,
        datosReceta,
      });
      return response.data as IDescontarResponse;
    } catch (error: any) {
      const message = error.response?.data?.detail || error.response?.data?.message || error.message;
      if (error.response?.status === 400) {
        throw new Error(`stock insuficiente: ${message}`);
      }
      throw new Error(`Error comunicando con backend Python: ${message}`);
    }
  }

  public async compensar(
    ventaId: string,
    lineas: ILineaDescontar[],
  ): Promise<ICompensarResponse> {
    try {
      console.log(`[HttpInventoryProvider] Compensando stock para venta ${ventaId}`);
      const response = await this.client.post('/api/v1/inventario/compensar', {
        ventaId,
        lineas,
      });
      return response.data as ICompensarResponse;
    } catch (error: any) {
      const message = error.response?.data?.detail || error.response?.data?.message || error.message;
      throw new Error(`Fallo crítico en compensación: ${message}`);
    }
  }

  public async validarDisponibilidad(
    codigoProducto: string,
    cantidad: number,
  ): Promise<boolean> {
    try {
      const response = await this.client.get('/api/v1/inventario/validar', {
        params: { codigoProducto, cantidad },
      });
      return response.data?.disponible ?? false;
    } catch {
      return false;
    }
  }
}