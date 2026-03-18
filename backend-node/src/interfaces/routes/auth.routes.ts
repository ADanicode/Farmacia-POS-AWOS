import { Router } from 'express';
import { IAuthService } from '@application/interfaces/IAuthService';
import { AuthController } from '@interfaces/controllers/AuthController';
import { requireAuth } from '@interfaces/middlewares';

export function createAuthRoutes(authService: IAuthService): Router {
  const router = Router();
  const authController = new AuthController(authService);

  router.post('/login', (req, res) => authController.login(req, res));

  router.post('/register', async (req, res) => {
    try {
      await (authService as any).registrarPerfil(req.body);
      res.status(201).json({ success: true, message: "✅ Perfil creado en Firestore" });
    } catch (error: any) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  router.post('/logout', requireAuth(authService), (req, res) => authController.logout(req, res));
  router.get('/me', requireAuth(authService), (req, res) => authController.getMe(req, res));

  return router;
}

export default createAuthRoutes;
