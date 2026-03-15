/**
 * @fileoverview Middleware requirePermissions - Validación de RBAC
 * Verifica que el usuario tenga todos los permisos requeridos
 */

import { Request, Response, NextFunction } from 'express';

/**
 * Middleware de autorización basado en permisos
 * Verifica que el usuario autenticado (en request.user) tenga TODOS los permisos requeridos
 * Debe ejecutarse después de requireAuth (que inyecta request.user)
 *
 * Uso:
 * router.post(
 *   '/api/ventas/procesar',
 *   requireAuth(authService),
 *   requirePermissions('crear_venta', 'descontar_stock'),
 *   ventasController.procesar
 * )
 *
 * @param permisos - Array de permisos requeridos
 * @returns Función middleware de Express
 */
export function requirePermissions(...permisos: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    // Verificar que el usuario está autenticado (request.user existe)
    if (!req.user) {
      res.status(401).json({
        success: false,
        error: 'No autenticado. Ejecute requireAuth primero.',
      });
      return;
    }

    // Verificar que el usuario tiene TODOS los permisos requeridos
    const userPermisos = req.user.permisos || [];
    const tienePermisos = permisos.every((p) => userPermisos.includes(p));

    if (!tienePermisos) {
      const permisosRequeridos = permisos.filter((p) => !userPermisos.includes(p));
      res.status(403).json({
        success: false,
        error: 'Permisos insuficientes',
        permisosRequeridos,
        permisosDelUsuario: userPermisos,
      });
      return;
    }

    // Usuario tiene todos los permisos requeridos
    next();
  };
}
