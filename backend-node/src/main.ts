/**
 * @fileoverview Punto de entrada principal de la aplicación
 * Bootstrap del servidor Express con inyección de dependencias
 */

import * as dotenv from 'dotenv';
import { createApp } from './app';
import {
  initializeFirebase,
  getFirestore,
} from '@config/firebase.config';
import { getJWTConfig } from '@config/jwt.config';
import { FirebaseAuthService } from '@infrastructure/external/FirebaseAuthService';
import { HttpInventoryProvider } from '@infrastructure/external/HttpInventoryProvider';
import { FirestorePerfilesRepository } from '@infrastructure/repositories/FirestorePerfilesRepository';
import { FirestoreVentaRepository } from '@infrastructure/repositories/FirestoreVentaRepository';
import { VentaService } from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService'; // <-- FIX 1: Importar ReporteService

// Cargar variables de entorno
dotenv.config();

async function bootstrap(): Promise<void> {
  try {
    console.log('Iniciando Farmacia POS - Backend Node.js');

    // 1. VALIDAR VARIABLES DE ENTORNO
    const requiredEnvVars = [
      'FIREBASE_PROJECT_ID',
      'FIREBASE_PRIVATE_KEY',
      'FIREBASE_CLIENT_EMAIL',
      'JWT_SECRET',
      'API_PORT',
    ];

    const missingVars = requiredEnvVars.filter((env) => !process.env[env]);
    if (missingVars.length > 0) {
      throw new Error(`Variables de entorno faltantes: ${missingVars.join(', ')}`);
    }

    // 2. INICIALIZAR FIREBASE ADMIN SDK
    const firebaseApp = initializeFirebase();
    const firestore = getFirestore();
    console.log(`✅ Firebase Admin SDK inicializado`);

    // 3. CREAR DEPENDENCIAS CON INYECCIÓN
    const jwtConfig = getJWTConfig();

    // Repositorios
    const perfilesRepository = new FirestorePerfilesRepository(firestore);
    const ventaRepository = new FirestoreVentaRepository(firestore);
    console.log('✅ Repositorios inicializados');

    // Servicios
    const authService = new FirebaseAuthService(
      firebaseApp,
      perfilesRepository,
      jwtConfig,
    );

    const inventoryProvider = new HttpInventoryProvider(
      process.env.PYTHON_INVENTORY_URL || 'http://localhost:5000',
    );

    // FIX 2: Instanciar ReporteService antes que el App
    const reporteService = new ReporteService(ventaRepository);
    console.log('✅ ReporteService creado e inyectado');

    const ventaService = new VentaService(ventaRepository, inventoryProvider);
    console.log('✅ VentaService creado');

    // ========================================
    // 4. CREAR Y CONFIGURAR EXPRESS
    // ========================================
    // FIX 3: Pasar el reporteService a createApp
    const app = createApp(authService, ventaService, reporteService);
    console.log('✅ Aplicación Express configurada');

    // 5. LEVANTAR SERVIDOR
    const port = parseInt(process.env.API_PORT || '3000', 10);
    app.listen(port, () => {
      console.log('');
      console.log('╔════════════════════════════════════════════════════════╗');
      console.log(`║   🎯 Servidor Express escuchando en puerto ${port}          ║`);
      console.log(`║   📍 http://localhost:${port}                               ║`);
      console.log('║                                                        ║');
      console.log('║   Endpoints disponibles:                               ║');
      console.log('║   POST   /api/auth/login      - Google SSO login       ║');
      console.log('║   POST   /api/ventas/procesar  - Crear venta (Saga)     ║');
      console.log('║   GET    /api/ventas/:id       - Obtener venta         ║');
      console.log('║   GET    /api/reportes/turno   - HU-35 (Nuevo)         ║'); // Muestra que ya hay reportes
      console.log('╚════════════════════════════════════════════════════════╝');
    });

  } catch (error) {
    console.error('❌ Error fatal durante bootstrap:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  bootstrap().catch((error) => {
    console.error('Error no capturado:', error);
    process.exit(1);
  });
}

export { bootstrap };
