/**
 * @fileoverview Rutas de Autenticación (HU-01, HU-02, HU-03, HU-04, HU-05)
 * Configura los endpoints HTTP para login/logout y gestión de sesión
 */

import { Router } from 'express';
import { IAuthService } from '@application/interfaces/IAuthService';
import { AuthController } from '@interfaces/controllers/AuthController';
import { requireAuth, requirePermissions } from '@interfaces/middlewares';

/**
 * Factory function para crear el router de autenticación
 * Requiere inyección de IAuthService para desacoplamiento
 *
 * @param authService - Servicio de autenticación inyectado
 * @returns Router de Express configurado
 */
export function createAuthRoutes(authService: IAuthService): Router {
  const router = Router();
  const authController = new AuthController(authService);

  /**
   * POST /api/auth/login
   * Inicio de sesión con Google SSO (HU-01)
   * Body: { idToken: string }
   * Response: { token, permisos, usuario, expiresIn }
   */
  router.post('/login', (req, res) => authController.login(req, res));

  /**
   * POST /api/auth/logout
   * Cierre de sesión (HU-02)
   * Nota: El logout real ocurre en el cliente eliminando el token
   * Este endpoint es principalmente para auditoría
   */
  router.post(
    '/logout',
    requireAuth(authService),
    (req, res) => authController.logout(req, res),
  );

  /**
   * GET /api/auth/me
   * Obtiene los datos del usuario autenticado
   * Requiere autenticación
   */
  router.get(
    '/me',
    requireAuth(authService),
    (req, res) => authController.getMe(req, res),
  );

  return router;
}

export default createAuthRoutes;
