/**
 * @fileoverview Configuración principal de Express
 * Monta todos los middlewares globales y rutas
 */

import express, { Express } from 'express';
import {
  globalErrorHandler,
  notFoundHandler,
} from '@interfaces/middlewares';
import { createAuthRoutes } from '@interfaces/routes/auth.routes';
import { createVentasRoutes } from '@interfaces/routes/ventas.routes';
import { IAuthService } from '@application/interfaces/IAuthService';
import { VentaService } from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService'; // <-- FIX 1: Importar ReporteService

/**
 * Crea y configura la aplicación Express
 * @param authService - Servicio de autenticación
 * @param ventaService - Servicio de ventas
 * @param reporteService - Servicio de reportes (NUEVO)
 */
export function createApp(
  authService: IAuthService, 
  ventaService: VentaService,
  reporteService: ReporteService // <-- FIX 2: Agregar al parámetro
): Express {
  const app = express();

  // ========================================
  // MIDDLEWARES GLOBALES
  // ========================================
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // CUMPLE HU-01/HU-17 FRONTEND WEB: habilita CORS para Flutter Web en dev y producción
  app.use((req, res, next) => {
    const origin = req.headers.origin as string;
    
    // En producción, aceptar solo el dominio de Railway web
    // En desarrollo, aceptar localhost
    const allowedOrigins = [
      'https://farmacia-pos-awos-production.up.railway.app',
      'http://localhost:3000',
      'http://localhost:8080',
      'http://192.168.1.1:8080', // Para testing local
    ];
    
    if (allowedOrigins.includes(origin)) {
      res.header('Access-Control-Allow-Origin', origin);
    }
    
    res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-KEY');
    res.header('Access-Control-Allow-Credentials', 'true');

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
  // HEALTH CHECK
  // ========================================
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  });

  // ========================================
  // RUTAS DE NEGOCIO
  // ========================================

  // Rutas de Autenticación
  app.use('/api/auth', createAuthRoutes(authService));

  // Rutas de Ventas (Saga Pattern)
  // FIX 3: Ahora pasamos los 3 servicios en el orden correcto
  app.use('/api/ventas', createVentasRoutes(ventaService, reporteService, authService));

  // ========================================
  // MANEJO DE ERRORES
  // ========================================
  app.use(notFoundHandler);
  app.use(globalErrorHandler);

  return app;
}