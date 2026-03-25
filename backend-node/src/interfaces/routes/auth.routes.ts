import { Router, Request, Response, NextFunction } from 'express';
import { IAuthService } from '@application/interfaces/IAuthService';
import { AuthController } from '@interfaces/controllers/AuthController';
import { requireAuth } from '@interfaces/middlewares';

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
      'Authentication requires Firebase credentials that are not yet available.',
  });
}

export function createAuthRoutes(
  authService: IAuthService,
  firebaseAvailable: boolean = true,
): Router {
  const router = Router();

  if (!firebaseAvailable) {
    // All auth routes return 503 when Firebase is absent
    router.use(firebaseUnavailable);
    return router;
  }

  const authController = new AuthController(authService);

  router.post('/login', (req, res) => authController.login(req, res));

  router.post('/register', async (req, res) => {
    try {
      await (authService as any).registrarPerfil(req.body);
      res.status(201).json({ success: true, message: '✅ Perfil creado en Firestore' });
    } catch (error: any) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  router.post('/logout', requireAuth(authService), (req, res) =>
    authController.logout(req, res),
  );
  router.get('/me', requireAuth(authService), (req, res) =>
    authController.getMe(req, res),
  );

  return router;
}

export default createAuthRoutes;
