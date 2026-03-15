/**
 * @fileoverview Archivo de ejemplo y documentación del flujo de Autenticación
 * SECURITY ARCHITECTURE - Módulo de Seguridad Blindado
 *
 * Este archivo documenta cómo se inicializa y utiliza el AuthService
 * en la aplicación Node.js/Express
 */

import * as admin from 'firebase-admin';
import { initializeFirebase, getFirestore } from '@config/firebase.config';
import { getJWTConfig } from '@config/jwt.config';
import { FirebaseAuthService } from '@infrastructure/external/FirebaseAuthService';
import { FirestorePerfilesRepository } from '@infrastructure/repositories/FirestorePerfilesRepository';
import { IAuthService } from '@application/interfaces/IAuthService';
import { validarLoginDTO } from '@application/dtos/LoginDTO';

/**
 * ============================================================================
 * FLUJO DE AUTENTICACIÓN - Arquitectura Hexagonal
 * ============================================================================
 *
 * 1. INICIALIZACIÓN (A la hora de levantar la app)
 *    ↓
 * 2. USUARIO FRONTEND: Completa login con Google
 *    └─ Obtiene: idToken de Google
 *    ↓
 * 3. FRONTEND ENVÍA: POST /api/auth/login { idToken }
 *    ↓
 * 4. AuthController.login()
 *    ├─ Valida DTO con Zod
 *    ├─ Llama a AuthService.login(loginDTO)
 *    ↓
 * 5. FirebaseAuthService.login()
 *    ├─ ✅ Verifica idToken con firebase-admin
 *    ├─ ✅ Consulta perfil en Firestore (perfiles_seguridad)
 *    ├─ ✅ Verifica que usuario esté activo
 *    ├─ ✅ Genera JWT interno con permisos
 *    └─ Retorna { token, permisos, usuario, expiresIn }
 *    ↓
 * 6. FRONTEND RECIBE: JWT + Permisos
 *    └─ Guarda en localStorage/SessionStorage
 *    ↓
 * 7. SOLICITUDES POSTERIORES: Incluyen JWT en header Authorization
 *    └─ GET /api/ventas/procesar
 *        Authorization: Bearer eyJhbGc...8NiIsIn...
 *    ↓
 * 8. Middleware requireAuth()
 *    ├─ Extrae token de header
 *    ├─ Llama a AuthService.verificarToken(token)
 *    ├─ ✅ Valida firma del JWT
 *    ├─ ✅ Verifica que no esté expirado
 *    └─ Inyecta payload en request.user
 *    ↓
 * 9. Middleware requirePermissions(['crear_venta'])
 *    ├─ Verifica que request.user.permisos incluya permiso requerido
 *    └─ Continúa o rechaza con 403
 *    ↓
 * 10. CONTROLADOR accede a request.user.permisos
 *     └─ Ejecuta lógica de negocio con seguridad garantizada
 *
 * ============================================================================
 */

/**
 * EJEMPLO DE INICIALIZACIÓN EN main.ts
 *
 * function bootstrap() {
 *   const firebaseApp = initializeFirebase();
 *   const firestore = getFirestore();
 *   const jwtConfig = getJWTConfig();
 *
 *   const perfilesRepository = new FirestorePerfilesRepository(firestore);
 *   const authService = new FirebaseAuthService(
 *     firebaseApp,
 *     perfilesRepository,
 *     jwtConfig,
 *   );
 *
 *   // Pasar authService a controllers y middlewares
 * }
 */

/**
 * EJEMPLO DE USO EN AuthController
 *
 * export class AuthController {
 *   constructor(private authService: IAuthService) {}
 *
 *   @Post('/login')
 *   async login(req: Request, res: Response) {
 *     try {
 *       const loginDTO = validarLoginDTO(req.body);
 *       const authToken = await this.authService.login(loginDTO);
 *       res.json(authToken);
 *     } catch (error) {
 *       res.status(401).json({ error: error.message });
 *     }
 *   }
 * }
 */

/**
 * EJEMPLO DE MIDDLEWARE requireAuth
 *
 * export function requireAuth(authService: IAuthService) {
 *   return async (req: Request, res: Response, next: NextFunction) => {
 *     const token = req.headers.authorization?.split(' ')[1];
 *     if (!token) {
 *       return res.status(401).json({ error: 'Token no proporcionado' });
 *     }
 *
 *     try {
 *       const payload = await authService.verificarToken(token);
 *       (req as any).user = payload;
 *       next();
 *     } catch (error) {
 *       res.status(401).json({ error: error.message });
 *     }
 *   };
 * }
 */

/**
 * EJEMPLO DE MIDDLEWARE requirePermissions
 *
 * export function requirePermissions(...permisos: string[]) {
 *   return (req: Request, res: Response, next: NextFunction) => {
 *     const user = (req as any).user;
 *     if (!user) {
 *       return res.status(401).json({ error: 'No autenticado' });
 *     }
 *
 *     const tienePermisos = permisos.every((p) =>
 *       user.permisos.includes(p)
 *     );
 *     if (!tienePermisos) {
 *       return res.status(403).json({
 *         error: `Permisos requeridos: ${permisos.join(', ')}`,
 *       });
 *     }
 *
 *     next();
 *   };
 * }
 */

/**
 * RUTAS PROTEGIDAS CON SEGURIDAD
 *
 * router.post(
 *   '/ventas/procesar',
 *   requireAuth(authService),
 *   requirePermissions('crear_venta', 'descontar_stock'),
 *   ventasController.procesar.bind(ventasController),
 * );
 */

export const SECURITY_DOCS = {
  version: '1.0.0',
  lastUpdated: '2026-03-13',
  implementedStandards: [
    'OAuth 2.0 (Google SSO)',
    'JWT (JSON Web Tokens)',
    'Inyección de Dependencias',
    'Arquitectura Hexagonal',
    'RBAC (Role-Based Access Control)',
  ],
  historasDeUsuario: [
    'HU-01: Inicio de Sesión Seguro con Google SSO',
    'HU-02: Cierre de Sesión inmediato',
    'HU-03: Restricción de Vistas Financieras para Cajero',
    'HU-04: Registro de Nuevos Empleados',
    'HU-05: Revocación inmediata de acceso',
  ],
  tecnologias: [
    'firebase-admin (verificación de tokens)',
    'jsonwebtoken (JWT)',
    'Firestore (perfiles_seguridad)',
    'Zod (validación)',
  ],
};
