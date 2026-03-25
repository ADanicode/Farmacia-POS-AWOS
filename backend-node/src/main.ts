/**
 * @fileoverview Punto de entrada principal de la aplicación
 * Bootstrap del servidor Express con inyección de dependencias
 *
 * Firebase is optional. When credentials are absent the server starts in
 * limited mode: health checks work, but Firebase-dependent endpoints return
 * 503 Service Unavailable until credentials are provided.
 */

import * as dotenv from 'dotenv';
import { createApp } from './app';
import {
  tryInitializeFirebase,
  getFirestore,
  isFirebaseInitialized,
} from '@config/firebase.config';
import { getJWTConfig } from '@config/jwt.config';
import { FirebaseAuthService } from '@infrastructure/external/FirebaseAuthService';
import { HttpInventoryProvider } from '@infrastructure/external/HttpInventoryProvider';
import { FirestorePerfilesRepository } from '@infrastructure/repositories/FirestorePerfilesRepository';
import { FirestoreVentaRepository } from '@infrastructure/repositories/FirestoreVentaRepository';
import { VentaService } from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService';
import { IAuthService } from '@application/interfaces/IAuthService';

// Cargar variables de entorno
dotenv.config();

async function bootstrap(): Promise<void> {
  try {
    console.log('Iniciando Farmacia POS - Backend Node.js');

    // 1. VALIDAR VARIABLES DE ENTORNO MÍNIMAS
    //    Only JWT_SECRET and API_PORT are strictly required to start the server.
    //    Firebase credentials are optional — their absence triggers limited mode.
    const requiredEnvVars = ['JWT_SECRET', 'API_PORT'];

    const missingVars = requiredEnvVars.filter((env) => !process.env[env]);
    if (missingVars.length > 0) {
      throw new Error(
        `Variables de entorno faltantes: ${missingVars.join(', ')}`,
      );
    }

    // 2. INTENTAR INICIALIZAR FIREBASE (opcional)
    let authService: IAuthService | null = null;
    let ventaService: VentaService | null = null;
    let reporteService: ReporteService | null = null;

    const firebaseApp = tryInitializeFirebase();

    if (firebaseApp && isFirebaseInitialized()) {
      console.log('✅ Firebase Admin SDK inicializado');

      // 3. CREAR DEPENDENCIAS CON INYECCIÓN
      const jwtConfig = getJWTConfig();
      const firestore = getFirestore();

      // Repositorios
      const perfilesRepository = new FirestorePerfilesRepository(firestore);
      const ventaRepository = new FirestoreVentaRepository(firestore);
      console.log('✅ Repositorios inicializados');

      // Servicios
      authService = new FirebaseAuthService(
        firebaseApp,
        perfilesRepository,
        jwtConfig,
      );

      const inventoryProvider = new HttpInventoryProvider(
        process.env.PYTHON_INVENTORY_URL || 'http://localhost:5000',
      );

      reporteService = new ReporteService(ventaRepository);
      console.log('✅ ReporteService creado e inyectado');

      ventaService = new VentaService(ventaRepository, inventoryProvider);
      console.log('✅ VentaService creado');
    } else {
      console.warn(
        '⚠️  Iniciando en modo limitado — endpoints de Firebase no disponibles.',
      );
    }

    // 4. CREAR Y CONFIGURAR EXPRESS
    const firebaseAvailable = isFirebaseInitialized();
    const app = createApp(
      authService,
      ventaService,
      reporteService,
      firebaseAvailable,
    );
    console.log('✅ Aplicación Express configurada');

    // 5. LEVANTAR SERVIDOR
    const port = parseInt(process.env.API_PORT || '3000', 10);
    app.listen(port, () => {
      console.log('');
      console.log(
        '╔════════════════════════════════════════════════════════╗',
      );
      console.log(
        `║   🎯 Servidor Express escuchando en puerto ${port}          ║`,
      );
      console.log(
        `║   📍 http://localhost:${port}                               ║`,
      );
      console.log(
        '║                                                        ║',
      );
      if (firebaseAvailable) {
        console.log(
          '║   Endpoints disponibles:                               ║',
        );
        console.log(
          '║   POST   /api/auth/login      - Google SSO login       ║',
        );
        console.log(
          '║   POST   /api/ventas/procesar  - Crear venta (Saga)     ║',
        );
        console.log(
          '║   GET    /api/ventas/:id       - Obtener venta         ║',
        );
        console.log(
          '║   GET    /api/reportes/turno   - HU-35 (Nuevo)         ║',
        );
      } else {
        console.log(
          '║   ⚠️  MODO LIMITADO: Firebase no configurado           ║',
        );
        console.log(
          '║   GET    /health              - Health check (activo)  ║',
        );
        console.log(
          '║   Todos los demás endpoints retornan 503               ║',
        );
      }
      console.log(
        '╚════════════════════════════════════════════════════════╝',
      );
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
