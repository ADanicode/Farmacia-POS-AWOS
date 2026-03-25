/**
 * @fileoverview Configuración principal de Express
 * Monta todos los middlewares globales y rutas
 */

import express, { Express } from 'express';
import cors from 'cors';
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

  // CUMPLE HU-01/HU-17 FRONTEND WEB: CORS para Flutter Web usando paquete cors
  const corsOptions = {
    origin: [
      'https://farmacia-pos-awos-production.up.railway.app',
      'http://localhost:3000',
      'http://localhost:8080',
      'http://127.0.0.1:8080',
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Origin', 'X-Requested-With', 'Content-Type', 'Accept', 'Authorization', 'X-API-KEY'],
    optionsSuccessStatus: 200,
  };

  app.use(cors(corsOptions));

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