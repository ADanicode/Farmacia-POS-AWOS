/**
 * @fileoverview Puerto de aplicación para servicios de autenticación
 * Define el contrato que cualquier proveedor de autenticación debe cumplir
 */

import { LoginDTO, JWTPayload } from '../dtos/LoginDTO';

/**
 * Interface para la respuesta de autenticación exitosa
 */
export interface IAuthToken {
  /**
   * JWT generado internamente
   */
  token: string;

  /**
   * Permisos autorizados para el usuario
   */
  permisos: string[];

  /**
   * Datos del usuario autenticado
   */
  usuario: {
    uid: string;
    email: string;
    nombre: string;
    role: string;
  };

  /**
   * Tiempo de expiración en segundos
   */
  expiresIn: number;
}

/**
 * Interface para el payload decodificado de un JWT
 */
export interface ITokenPayload extends JWTPayload {
  iat?: number;
  exp?: number;
}

/**
 * Puerto de aplicación: IAuthService
 * Responsable de:
 * 1. Verificar tokens de Google con Firebase
 * 2. Consultar roles y permisos en Firestore
 * 3. Emitir JWTs propios con permisos
 * 4. Validar JWTs en solicitudes posteriores
 *
 * Implementaciones:
 * - FirebaseAuthService (producción)
 * - MockAuthService (tests)
 */
export interface IAuthService {
  /**
   * Realiza login SSO con Google
   * Flujo (HU-01):
   * 1. Recibe idToken de Google
   * 2. Verifica con firebase-admin
   * 3. Busca perfil en Firestore (perfiles_seguridad)
   * 4. Genera JWT interno con permisos
   *
   * @param loginDTO - DTO con idToken de Google
   * @returns Token JWT con permisos del usuario
   * @throws {FirebaseAuthError} Si idToken es inválido o expirado
   * @throws {NotFoundError} Si el usuario no tiene perfil en Firestore
   * @throws {UnauthorizedError} Si el usuario está desactivado
   */
  login(loginDTO: LoginDTO): Promise<IAuthToken>;

  /**
   * Verifica y decodifica un JWT generado internamente
   * Se utiliza en middlewares para autorizar solicitudes
   *
   * @param token - JWT a verificar
   * @returns Payload decodificado del token
   * @throws {JwtError} Si el token es inválido, expirado o está firmado incorrectamente
   */
  verificarToken(token: string): Promise<ITokenPayload>;

  /**
   * Refresca un JWT expirado (opcional)
   * @param token - JWT antiguo
   * @returns Nuevo JWT con mismos permisos
   */
  refrescarToken?(token: string): Promise<IAuthToken>;
}
