import { Router, Request, Response, NextFunction } from 'express';
import { VentasController } from '@interfaces/controllers/VentasController';
import { VentaService } from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService';
import { IAuthService } from '@application/interfaces/IAuthService';
import { requireAuth, requirePermissions } from '@interfaces/middlewares';

/**
 * Middleware that returns 503 when Firebase is not available.
 * Used as a per-route guard so individual routes can be protected even if the
 * router is mounted (e.g. during testing or partial initialization).
 */
function firebaseUnavailable(
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  res.status(503).json({
    success: false,
    error: 'Firebase not configured',
    message:
      'Sales endpoints require Firebase credentials that are not yet available.',
  });
}

export function createVentasRoutes(
  ventaService: VentaService,
  reporteService: ReporteService,
  authService: IAuthService,
  firebaseAvailable: boolean = true,
): Router {
  const router = Router();

  if (!firebaseAvailable) {
    // All ventas routes return 503 when Firebase is absent
    router.use(firebaseUnavailable);
    return router;
  }

  const ventasController = new VentasController(
    ventaService,
    reporteService,
    authService,
  );

  /**
   * POST /api/ventas/procesar
   * IMPORTANTE: requireAuth necesita recibir el authService para validar el token
   */
  router.post(
    '/procesar',
    requireAuth(authService),
    requirePermissions('crear_venta'),
    (req: Request, res: Response) => ventasController.procesar(req, res),
  );

  router.get(
    '/reporte/turno',
    requireAuth(authService),
    (req, res) => ventasController.obtenerReporteTurno(req, res),
  );

  /**
   * GET /api/ventas/:ventaId
   */
  router.get(
    '/:ventaId',
    requireAuth(authService),
    (req: Request, res: Response) => ventasController.obtener(req, res),
  );

  return router;
}
