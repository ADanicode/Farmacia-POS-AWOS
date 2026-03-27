/**
 * @fileoverview VentasController - Controlador de Ventas Completo
 * Maneja el flujo de transacciones (Saga) y la generación de reportes (HU-28 a HU-39)
 */

import { Request, Response } from 'express';
import { 
  VentaService, 
  StockInsuficienteError, 
  CompensacionFallidaError, 
  VentaServiceError 
} from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService';
import { IAuthService } from '@application/interfaces/IAuthService';
import { validarCreateVentaDTO } from '@application/dtos/CreateVentaDTO';
import { ZodError } from 'zod';

export class VentasController {
  constructor(
    private readonly ventaService: VentaService,
    private readonly reporteService: ReporteService,
    private readonly authService: IAuthService,
  ) {}

  /**
   * POST /api/ventas/procesar
   * Registra una nueva venta en el sistema.
   */
  public async procesar(req: Request, res: Response): Promise<void> {
    const usuarioAuth = (req as any).user;

    try {
      console.log(`[VentasController] 📥 Procesando venta - Usuario: ${usuarioAuth.uid}`);

      // 1. Validar DTO
      const createVentaDTO = validarCreateVentaDTO(req.body);

      // 2. Verificación de Seguridad básica
      if (usuarioAuth.uid !== createVentaDTO.usuarioId) {
        res.status(403).json({
          success: false,
          error: 'No puedes crear ventas para otro usuario',
        });
        return;
      }

      // 3. Recrear Entidad Usuario (Mínima para el Service)
      const { Usuario, RoleType, PermissionType } = require('@domain/entities/Usuario');
      const usuarioTemporal = Usuario.crear(
        usuarioAuth.uid,
        usuarioAuth.email,
        usuarioAuth.nombre || 'Usuario',
        usuarioAuth.role === 'cajero' ? RoleType.CAJERO : RoleType.VENDEDOR,
        usuarioAuth.permisos || []
      );

      // 4. Ejecutar Orquestación (Saga Pattern)
      const ventaProcesada = await this.ventaService.crearVenta(
        usuarioTemporal,
        createVentaDTO,
      );

      // 5. Respuesta Exitosa
      res.status(200).json({
        success: true,
        data: {
          ventaId: ventaProcesada.getId(),
          total: ventaProcesada.getTotal(),
          montoRecibido: ventaProcesada.getMontoRecibido(),
          estado: ventaProcesada.getEstado(),
          fechaVenta: ventaProcesada.getFechaVenta().toISOString(),
          cambio: ventaProcesada.getCambio()
        }
      });

    } catch (error: any) {
      this.manejarErroresVenta(error, res);
    }
  }

  /**
   * GET /api/ventas/reporte/turno
   * HU-35: Obtiene el resumen de ventas del cajero actual (Samuel)
   */
  public async obtenerReporteTurno(req: Request, res: Response): Promise<void> {
    try {
      const usuarioAuth = (req as any).user;
      console.log(`[VentasController] 📊 Generando reporte para: ${usuarioAuth.uid}`);

      const reporte = await this.reporteService.obtenerVentasPorTurno(usuarioAuth.uid);

      res.status(200).json({
        success: true,
        data: reporte
      });
    } catch (error: any) {
      console.error(`[VentasController] Error en reporte:`, error.message);
      res.status(500).json({
        success: false,
        error: 'Error al generar reporte de turno',
        message: error.message
      });
    }
  }

  /**
   * GET /api/ventas/:ventaId
   * Recupera un ticket específico por su folio.
   */
  public async obtener(req: Request, res: Response): Promise<void> {
    try {
      const { ventaId } = req.params;
      const venta = await this.ventaService.obtenerVenta(ventaId);

      res.status(200).json({
        success: true,
        data: venta
      });
    } catch (error: any) {
      res.status(404).json({
        success: false,
        error: 'Venta no encontrada'
      });
    }
  }

  /**
   * POST /api/ventas/:ventaId/anular
   * HU-37: Anulación segura de ventas con trazabilidad.
   */
  public async anular(req: Request, res: Response): Promise<void> {
    try {
      const { ventaId } = req.params;
      const usuarioAuth = (req as any).user;
      const motivo = String(req.body?.motivo ?? '').trim();

      if (!motivo) {
        res.status(400).json({
          success: false,
          error: 'El motivo de anulación es obligatorio',
        });
        return;
      }

      const venta = await this.ventaService.anularVenta(
        ventaId,
        motivo,
        usuarioAuth.uid,
      );

      res.status(200).json({
        success: true,
        data: {
          ventaId: venta.getId(),
          estado: venta.getEstado(),
          razonAnulacion: motivo,
        },
      });
    } catch (error: any) {
      if (error.message?.toLowerCase().includes('no encontrada')) {
        res.status(404).json({
          success: false,
          error: 'Venta no encontrada',
        });
        return;
      }

      console.error(`[VentasController] Error en anulación:`, error);
      res.status(500).json({
        success: false,
        error: error.message || 'Error al anular venta',
      });
    }
  }

  /**
   * Centralizador de manejo de errores para limpieza del código
   */
  private manejarErroresVenta(error: any, res: Response): void {
    if (error instanceof ZodError) {
      res.status(400).json({
        success: false,
        error: 'Validación de datos fallida',
        details: error.flatten().fieldErrors,
      });
    } else if (error instanceof StockInsuficienteError) {
      res.status(400).json({
        success: false,
        error: 'Stock insuficiente',
        details: error.detalles,
      });
    } else if (error instanceof CompensacionFallidaError) {
      res.status(500).json({
        success: false,
        error: 'FALLO CRÍTICO EN COMPENSACIÓN',
        ventaId: error.ventaId,
      });
    } else {
      console.error(`[VentasController] Error inesperado:`, error);
      res.status(500).json({
        success: false,
        error: error.message || 'Error interno del servidor',
      });
    }
  }
}
