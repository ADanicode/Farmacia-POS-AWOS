/**
 * @fileoverview Middleware requireAuth - Validación de JWT
 * Verifica que toda solicitud tenga un JWT válido en el header Authorization
 */

import { Request, Response, NextFunction } from 'express';
import { IAuthService } from '@application/interfaces/IAuthService';

/**
 * Interfaz extendida de Request para inyectar datos de usuario
 */
declare global {
  namespace Express {
    interface Request {
      user?: {
        uid: string;
        email: string;
        nombre?: string;
        role: string;
        permisos: string[];
        iat?: number;
        exp?: number;
      };
    }
  }
}

/**
 * Middleware de autenticación
 * Verifica que el JWT en el header Authorization sea válido
 * Si es válido, inyecta los datos del usuario en request.user
 * Si no es válido, rechaza la solicitud con 401
 *
 * Uso:
 * router.get('/api/protected', requireAuth(authService), controller.handle)
 *
 * @param authService - Servicio de autenticación inyectado
 * @returns Función middleware de Express
 */
export function requireAuth(authService: IAuthService) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      // Extraer token del header Authorization
      const authHeader = req.headers.authorization;
      if (!authHeader) {
        res.status(401).json({
          success: false,
          error: 'Authorization header no proporcionado',
        });
        return;
      }

      // Validar formato "Bearer <token>"
      const parts = authHeader.split(' ');
      if (parts.length !== 2 || parts[0] !== 'Bearer') {
        res.status(401).json({
          success: false,
          error: 'Formato de Authorization inválido. Use: Bearer <token>',
        });
        return;
      }

      const token = parts[1];

      // Verificar token con el servicio
      const payload = await authService.verificarToken(token);

      // Inyectar usuario en el request
      req.user = payload;

      // Continuar al siguiente middleware/controlador
      next();
    } catch (error: any) {
      if (error.message === 'Token expirado. Inicia sesión nuevamente.') {
        res.status(401).json({
          success: false,
          error: 'Token expirado',
          code: 'TOKEN_EXPIRED',
        });
        return;
      }

      if (error.message === 'Token inválido o mal firmado.') {
        res.status(401).json({
          success: false,
          error: 'Token inválido',
          code: 'INVALID_TOKEN',
        });
        return;
      }

      console.error('[requireAuth] Error al verificar token:', error);
      res.status(401).json({
        success: false,
        error: 'No autorizado',
      });
    }
  };
}
