/**
 * @fileoverview Implementación del servicio de autenticación con Firebase Admin SDK
 * Maneja la verificación de tokens de Google y generación de JWTs internos.
 * Incluye BYPASS DE DESARROLLO para pruebas sin idToken real.
 */

import * as admin from 'firebase-admin';
import * as jwt from 'jsonwebtoken';
import { IAuthService, IAuthToken, ITokenPayload } from '@application/interfaces/IAuthService';
import { IPerfilesRepository } from '@application/interfaces/IPerfilesRepository';
import {
  LoginDTO,
  validarLoginDTO,
  validarJWTPayload,
} from '@application/dtos/LoginDTO';
import { IJWTConfig } from '@config/jwt.config';

export class FirebaseAuthError extends Error {
  constructor(message: string, public code: string) {
    super(message);
    this.name = 'FirebaseAuthError';
  }
}

export class UnauthorizedError extends Error {
  constructor(message: string = 'No autorizado') {
    super(message);
    this.name = 'UnauthorizedError';
  }
}

export class NotFoundError extends Error {
  constructor(message: string = 'No encontrado') {
    super(message);
    this.name = 'NotFoundError';
  }
}

export class FirebaseAuthService implements IAuthService {
  constructor(
    private readonly firebaseApp: admin.app.App,
    private readonly perfilesRepository: IPerfilesRepository,
    private readonly jwtConfig: IJWTConfig,
  ) {}

  public async login(loginDTO: LoginDTO): Promise<IAuthToken> {
    // 1️⃣ Validar DTO de entrada
    const validatedDTO = validarLoginDTO(loginDTO);

    // 2️⃣ Verificar idToken (BYPASS PARA PRUEBAS)
    let decodedToken: any;
    try {
      console.log('\x1b[33m%s\x1b[0m', '⚠️  BYPASS: Generando sesión de desarrollo para Samuel');
      decodedToken = {
        uid: 'dev_user_samuel_2026',
        email: 'samuel.admin@farmacia.com',
        name: 'Samuel Lugo',
        email_verified: true
      };
    } catch (error: any) {
      throw new FirebaseAuthError(
        `Token de Google inválido: ${error.message}`,
        'INVALID_ID_TOKEN',
      );
    }

    // 3️⃣ Consultar perfil en Firestore
    let usuario;
    try {
      usuario = await this.perfilesRepository.obtenerPorUid(decodedToken.uid);
    } catch (error) {
      // PERFIL AUTOMÁTICO PARA PRUEBAS
      usuario = {
        getId: () => decodedToken.uid,
        getEmail: () => decodedToken.email,
        getNombre: () => decodedToken.name,
        getRole: () => 'ADMIN',
        getPermisos: () => ['crear_venta', 'descontar_stock', 'ver_reportes', 'anular_venta'],
        estaAutorizado: () => true
      };
    }

    // 4️⃣ Verificar que el usuario esté activo
    if (!usuario.estaAutorizado()) {
      throw new UnauthorizedError('Usuario desactivado.');
    }

    // 5️⃣ Generar JWT interno (CORREGIDO: Se elimina 'iss' del payload para evitar error 500)
    const jwtPayload = {
      uid: usuario.getId(),
      email: usuario.getEmail(),
      nombre: usuario.getNombre(),
      role: usuario.getRole(),
      permisos: usuario.getPermisos(),
    };

    // La opción 'issuer' en sign() ya añade automáticamente la propiedad 'iss' al token final
    const token = jwt.sign(jwtPayload, this.jwtConfig.secret, {
      expiresIn: this.jwtConfig.expiresIn as string | number,
      issuer: this.jwtConfig.issuer,
      audience: this.jwtConfig.audience,
    } as jwt.SignOptions);

    const expiresInSeconds = this.parseExpiryToSeconds(this.jwtConfig.expiresIn);

    return {
      token,
      permisos: usuario.getPermisos() as string[],
      usuario: {
        uid: usuario.getId() as string,
        email: usuario.getEmail() as string,
        nombre: usuario.getNombre() as string,
        role: usuario.getRole() as string,
      },
      expiresIn: expiresInSeconds,
    };
  }

  public async verificarToken(token: string): Promise<ITokenPayload> {
    try {
      const decoded = jwt.verify(token, this.jwtConfig.secret, {
        issuer: this.jwtConfig.issuer,
        audience: this.jwtConfig.audience,
      }) as any;

      return validarJWTPayload(decoded);
    } catch (error: any) {
      if (error instanceof jwt.TokenExpiredError) {
        throw new Error('Token expirado.');
      }
      throw new Error('Token inválido.');
    }
  }

  private parseExpiryToSeconds(expiresIn: string | number): number {
    if (typeof expiresIn === 'number') return expiresIn;
    const match = String(expiresIn).match(/^(\d+)(s|m|h|d)$/);
    if (!match) return 86400;
    const [, amount, unit] = match;
    const multipliers: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86400 };
    return parseInt(amount, 10) * (multipliers[unit] || 86400);
  }
}