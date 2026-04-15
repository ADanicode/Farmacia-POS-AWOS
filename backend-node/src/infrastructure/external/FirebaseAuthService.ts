import * as admin from 'firebase-admin';
import * as jwt from 'jsonwebtoken';
import { IAuthService, IAuthToken, ITokenPayload } from '@application/interfaces/IAuthService';
import { IPerfilesRepository } from '@application/interfaces/IPerfilesRepository';
import { Usuario } from '@domain/entities';
import { LoginDTO, validarLoginDTO, validarJWTPayload } from '@application/dtos/LoginDTO';
import { IJWTConfig } from '@config/jwt.config';

export class FirebaseAuthService implements IAuthService {
  constructor(
    private readonly firebaseApp: admin.app.App,
    private readonly perfilesRepository: IPerfilesRepository,
    private readonly jwtConfig: IJWTConfig,
  ) {}

  public async registrarPerfil(datos: any): Promise<void> {
    try {
      const nuevoUsuario = Usuario.desdeFirestore({
        id: datos.uid,
        email: datos.email,
        nombre: datos.nombre,
        role: (datos.role || 'ADMIN').toUpperCase(),
        permisos: datos.permisos || ['crear_venta', 'descontar_stock', 'ver_reportes', 'anular_venta'],
        activo: true,
        fechaCreacion: new Date().toISOString()
      });

      await this.perfilesRepository.crear(nuevoUsuario);
      console.log(`\x1b[32m%s\x1b[0m`, `✅ Firestore: Perfil de ${datos.nombre} creado.`);
    } catch (error: any) {
      throw new Error(`Error en persistencia: ${error.message}`);
    }
  }

  public async login(loginDTO: LoginDTO): Promise<IAuthToken> {
    const validatedDTO = validarLoginDTO(loginDTO);

    // Paso 1: Verificar idToken de Google
    let decodedToken: admin.auth.DecodedIdToken;
    try {
      decodedToken = await this.firebaseApp.auth().verifyIdToken(validatedDTO.idToken, true);
    } catch (error: any) {
      const authError = new Error(`idToken de Google inválido: ${error.message}`);
      authError.name = 'FirebaseAuthError';
      throw authError;
    }

    // Paso 2: Buscar DIRECTAMENTE por UID (la única fuente de verdad)
    // NUNCA hacer fallback a email - es anti-patrón en Firebase
    let usuario: Usuario;
    try {
      usuario = await this.perfilesRepository.obtenerPorUid(decodedToken.uid);
    } catch (error: any) {
      // Si no existe por UID, significa que el frontend no ha creado aún el perfil "sin_rol"
      const notFound = new Error(
        `Perfil no encontrado en Firestore para UID ${decodedToken.uid}. ` +
        `El usuario debe ser aprobado por un admin primero.`,
      );
      notFound.name = 'NotFoundError';
      throw notFound;
    }

    // Paso 3: Validar que el usuario esté activo
    if (!usuario.isActivo()) {
      const unauthorized = new Error(
        `Usuario ${decodedToken.uid} desactivado o pendiente de aprobación.`,
      );
      unauthorized.name = 'UnauthorizedError';
      throw unauthorized;
    }

    // Paso 4: Validar que tenga un rol válido (no "SIN_ROL")
    const role = String(usuario.getRole()).toUpperCase();
    if (role === 'SIN_ROL') {
      const unauthorized = new Error(
        `Usuario ${decodedToken.uid} no tiene rol asignado. Pendiente de aprobación del admin.`,
      );
      unauthorized.name = 'UnauthorizedError';
      throw unauthorized;
    }

    // Paso 5: Validar que tenga permisos
    const permisos = usuario.getPermisos();
    if (!permisos || permisos.length === 0) {
      const unauthorized = new Error(
        `Usuario ${decodedToken.uid} no tiene permisos asignados.`,
      );
      unauthorized.name = 'UnauthorizedError';
      throw unauthorized;
    }

    // Paso 6: Emitir JWT solo si TODO está válido
    const jwtPayload = {
      uid: usuario.getId(), email: usuario.getEmail(), nombre: usuario.getNombre(),
      role: usuario.getRole(), permisos: usuario.getPermisos(),
    };

    const token = jwt.sign(jwtPayload, this.jwtConfig.secret, {
      expiresIn: this.jwtConfig.expiresIn as string | number,
      issuer: this.jwtConfig.issuer, audience: this.jwtConfig.audience,
    } as jwt.SignOptions);

    return {
      token, permisos: usuario.getPermisos() as string[],
      usuario: { uid: usuario.getId(), email: usuario.getEmail(), nombre: usuario.getNombre(), role: usuario.getRole() },
      expiresIn: 86400,
    };
  }

  public async verificarToken(token: string): Promise<ITokenPayload> {
    const decoded = jwt.verify(token, this.jwtConfig.secret, {
      issuer: this.jwtConfig.issuer, audience: this.jwtConfig.audience,
    }) as any;
    return validarJWTPayload(decoded);
  }
}