/**
 * @fileoverview Configuración principal de Express
 * Monta todos los middlewares globales y rutas
 *
 * When `firebaseAvailable` is false the app runs in limited mode: the /health
 * endpoint always responds, but all Firebase-dependent routes return 503.
 */

import express, { Express, Request, Response, NextFunction } from 'express';
import {
  globalErrorHandler,
  notFoundHandler,
} from '@interfaces/middlewares';
import { createAuthRoutes } from '@interfaces/routes/auth.routes';
import { createVentasRoutes } from '@interfaces/routes/ventas.routes';
import { IAuthService } from '@application/interfaces/IAuthService';
import { VentaService } from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService';

/**
 * Middleware that rejects a request with 503 when Firebase is not available.
 */
function requireFirebase(req: Request, res: Response, next: NextFunction): void {
  res.status(503).json({
    success: false,
    error: 'Firebase not configured',
    message:
      'This endpoint requires Firebase credentials that are not yet available. ' +
      'Please configure FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, ' +
      'FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY_ID.',
  });
}

/**
 * Crea y configura la aplicación Express.
 *
 * @param authService    - Servicio de autenticación (null when Firebase is absent)
 * @param ventaService   - Servicio de ventas (null when Firebase is absent)
 * @param reporteService - Servicio de reportes (null when Firebase is absent)
 * @param firebaseAvailable - Whether Firebase was successfully initialized
 */
export function createApp(
  authService: IAuthService | null,
  ventaService: VentaService | null,
  reporteService: ReporteService | null,
  firebaseAvailable: boolean = false,
): Express {
  const app = express();

  // ========================================
  // MIDDLEWARES GLOBALES
  // ========================================
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // CUMPLE HU-01/HU-17 FRONTEND WEB: habilita acceso cross-origin para Flutter Web.
  app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-KEY');

    if (req.method === 'OPTIONS') {
      res.sendStatus(204);
      return;
    }

    next();
  });

  app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
  });

  // ========================================
  // HEALTH CHECK — always available
  // ========================================
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      firebase: firebaseAvailable ? 'connected' : 'unavailable',
    });
  });

  // ========================================
  // RUTAS DE NEGOCIO
  // ========================================
  if (firebaseAvailable && authService && ventaService && reporteService) {
    // Full mode — all services are available
    app.use('/api/auth', createAuthRoutes(authService));
    app.use(
      '/api/ventas',
      createVentasRoutes(ventaService, reporteService, authService),
    );
  } else {
    // Limited mode — return 503 for all Firebase-dependent routes
    app.use('/api/auth', requireFirebase);
    app.use('/api/ventas', requireFirebase);
  }

  // ========================================
  // MANEJO DE ERRORES
  // ========================================
  app.use(notFoundHandler);
  app.use(globalErrorHandler);

  return app;
}
