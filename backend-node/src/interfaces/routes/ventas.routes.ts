import { Router, Request, Response } from 'express'; // FIX 1: Importar Request y Response
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
  
  // FIX 2: Pasar los 3 argumentos en orden
  const ventasController = new VentasController(
    ventaService,
    reporteService,
    authService
  );

  router.post(
    '/procesar',
    requireAuth,
    // FIX 3: Si marca error con [], quita los corchetes: requirePermissions('crear_venta')
    requirePermissions('crear_venta'),
    (req: Request, res: Response) => ventasController.procesar(req, res), // FIX 4: Tipar req y res
  );

  router.get(
    '/:ventaId',
    requireAuth,
    (req: Request, res: Response) => ventasController.obtener(req, res), // FIX 4: Tipar req y res
  );

  return router;
}