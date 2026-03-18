import { Usuario } from '@domain/entities';

/**
 * Puerto de persistencia: IPerfilesRepository
 * Define las operaciones permitidas sobre la colección de perfiles
 */
export interface IPerfilesRepository {
  obtenerPorUid(uid: string): Promise<Usuario>;
  obtenerPorEmail(email: string): Promise<Usuario>;
  
  /**
   * Crea un nuevo perfil de usuario (HU-04)
   */
  crear(usuario: Usuario): Promise<Usuario>;

  actualizarPermisos(uid: string, permisos: string[]): Promise<Usuario>;
  desactivar(uid: string): Promise<Usuario>;
  activar(uid: string): Promise<Usuario>;
}
