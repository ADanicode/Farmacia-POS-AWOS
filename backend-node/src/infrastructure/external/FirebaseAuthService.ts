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
        role: (datos.role || 'admin').toLowerCase(),
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

    let decodedToken: admin.auth.DecodedIdToken;
    try {
      decodedToken = await this.firebaseApp.auth().verifyIdToken(validatedDTO.idToken, true);
    } catch (error: any) {
      const authError = new Error(`idToken de Google inválido: ${error.message}`);
      authError.name = 'FirebaseAuthError';
      throw authError;
    }

    let usuario: Usuario;
    try {
      usuario = await this.perfilesRepository.obtenerPorUid(decodedToken.uid);
    } catch (_) {
      try {
        usuario = await this.perfilesRepository.obtenerPorEmail(decodedToken.email || '');
      } catch (error: any) {
        const notFound = new Error(
          `Perfil no encontrado en Firestore para UID ${decodedToken.uid}`,
        );
        notFound.name = 'NotFoundError';
        throw notFound;
      }
    }

    if (!usuario.isActivo()) {
      const unauthorized = new Error('Usuario desactivado en perfiles_seguridad');
      unauthorized.name = 'UnauthorizedError';
      throw unauthorized;
    }

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