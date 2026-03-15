/**
 * @fileoverview Middleware global de manejo de errores
 * Captura cualquier error no manejado y retorna respuesta consistente
 */

import { Request, Response, NextFunction } from 'express';

/**
 * Middleware global de error
 * Debe montarse ÚLTIMO en la cadena de middlewares
 * Captura cualquier error lanzado por controladores o middlewares anteriores
 *
 * @param err - Error lanzado
 * @param req - Request de Express
 * @param res - Response de Express
 * @param next - NextFunction de Express
 */
export function globalErrorHandler(
  err: any,
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  console.error('[GlobalErrorHandler] Error no manejado:', {
    message: err.message,
    type: err.constructor.name,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  res.status(err.status || 500).json({
    success: false,
    error: err.message || 'Error interno del servidor',
    timestamp: new Date().toISOString(),
  });
}

/**
 * Middleware para rutas no encontradas (404)
 */
export function notFoundHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  res.status(404).json({
    success: false,
    error: 'Endpoint no encontrado',
    path: req.path,
    method: req.method,
  });
}
