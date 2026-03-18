import { Router, Request, Response } from 'express';
import { VentasController } from '@interfaces/controllers/VentasController';
import { VentaService } from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService';
import { IAuthService } from '@application/interfaces/IAuthService';
import { requireAuth, requirePermissions } from '@interfaces/middlewares';

export function createVentasRoutes(
  ventaService: VentaService,
  reporteService: ReporteService,
  authService: IAuthService,
): Router {
  const router = Router();
  
  const ventasController = new VentasController(
    ventaService,
    reporteService,
    authService
  );

  /**
   * POST /api/ventas/procesar
   * IMPORTANTE: requireAuth necesita recibir el authService para validar el token
   */
  router.post(
    '/procesar',
    requireAuth(authService), // ✅ FIX: Invocar con el servicio
  requirePermissions('crear_venta'), // ✅ FIX: Pasar como array si así lo espera el middleware
    (req: Request, res: Response) => ventasController.procesar(req, res),
  );

  // En createVentasRoutes...
router.get(
  '/reporte/turno',
  requireAuth(authService),
  (req, res) => ventasController.obtenerReporteTurno(req, res)
);

  /**
   * GET /api/ventas/:ventaId
   */
  router.get(
    '/:ventaId',
    requireAuth(authService), // ✅ FIX: Invocar con el servicio
    (req: Request, res: Response) => ventasController.obtener(req, res),
  );

  return router;
}