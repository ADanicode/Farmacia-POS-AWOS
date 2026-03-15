/**
 * @fileoverview AuthController - Controlador de Autenticación
 * Expone los endpoints HTTP para login/logout
 * Inyecta el IAuthService para manejar la lógica
 */

import { Request, Response } from 'express';
import { IAuthService } from '@application/interfaces/IAuthService';
import { validarLoginDTO } from '@application/dtos/LoginDTO';
import { ZodError } from 'zod';

/**
 * AuthController - Manejador de solicitudes de autenticación
 * Implementa el patrón de inyección de dependencias
 * Responsable de:
 * 1. Recibir y validar peticiones HTTP
 * 2. Delegar lógica al IAuthService (sin detalles de implementación)
 * 3. Formatea respuestas HTTP
 */
export class AuthController {
  /**
   * Constructor con inyección de dependencias
   * @param authService - Servicio de autenticación inyectado
   */
  constructor(private readonly authService: IAuthService) {}

  /**
   * POST /api/auth/login
   * Realiza login con idToken de Google
   * Flujo (HU-01):
   * 1. Valida que el body contenga idToken
   * 2. Llama a authService.login()
   * 3. Retorna JWT con permisos del usuario
   *
   * @param req - Request de Express
   * @param res - Response de Express
   * @returns JSON con { token, permisos, usuario, expiresIn }
   */
  public async login(req: Request, res: Response): Promise<void> {
    try {
      // Validar DTO de entrada con Zod
      const loginDTO = validarLoginDTO(req.body);

      // Delegar al servicio de autenticación
      const authToken = await this.authService.login(loginDTO);

      // Respuesta exitosa
      res.status(200).json({
        success: true,
        data: authToken,
      });
    } catch (error: any) {
      // Manejar errores de validación Zod
      if (error instanceof ZodError) {
        res.status(400).json({
          success: false,
          error: 'Validación fallida',
          details: error.errors,
        });
        return;
      }

      // Manejar errores de autenticación
      if (error.name === 'FirebaseAuthError') {
        res.status(401).json({
          success: false,
          error: 'Token de Google inválido o expirado',
          message: error.message,
        });
        return;
      }

      if (error.name === 'NotFoundError') {
        res.status(404).json({
          success: false,
          error: 'Usuario no encontrado',
          message: error.message,
        });
        return;
      }

      if (error.name === 'UnauthorizedError') {
        res.status(403).json({
          success: false,
          error: 'Usuario no autorizado',
          message: error.message,
        });
        return;
      }

      // Error genérico
      console.error('[AuthController] Error en login:', error);
      res.status(500).json({
        success: false,
        error: 'Error interno del servidor',
      });
    }
  }

  /**
   * POST /api/auth/logout
   * Realiza logout del usuario
   * En realidad, solo retorna un mensaje de éxito
   * El logout real se realiza en el frontend eliminando el token
   *
   * @param req - Request de Express
   * @param res - Response de Express
   * @returns JSON con confirmación de logout
   */
  public async logout(req: Request, res: Response): Promise<void> {
    try {
      res.status(200).json({
        success: true,
        message: 'Logout exitoso. Elimina el token del cliente.',
      });
    } catch (error) {
      console.error('[AuthController] Error en logout:', error);
      res.status(500).json({
        success: false,
        error: 'Error interno del servidor',
      });
    }
  }

  /**
   * GET /api/auth/me
   * Retorna los datos del usuario autenticado
   * Se ejecuta después del middleware requireAuth, por lo que tenemos el payload del JWT
   *
   * @param req - Request de Express (contiene user en algún campo custom)
   * @param res - Response de Express
   * @returns JSON con datos del usuario
   */
  public async getMe(req: Request, res: Response): Promise<void> {
    try {
      const user = (req as any).user;

      if (!user) {
        res.status(401).json({
          success: false,
          error: 'No autenticado',
        });
        return;
      }

      res.status(200).json({
        success: true,
        data: {
          uid: user.uid,
          email: user.email,
          nombre: user.nombre,
          role: user.role,
          permisos: user.permisos,
        },
      });
    } catch (error) {
      console.error('[AuthController] Error en getMe:', error);
      res.status(500).json({
        success: false,
        error: 'Error interno del servidor',
      });
    }
  }
}
