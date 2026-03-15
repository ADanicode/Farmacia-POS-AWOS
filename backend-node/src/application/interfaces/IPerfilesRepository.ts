/**
 * @fileoverview Puerto de persistencia para la colección perfiles_seguridad
 * Permite al AuthService consultar roles y permisos
 */

import { Usuario } from '@domain/entities';

/**
 * Puerto de persistencia: IPerfilesRepository
 * Abstrae el acceso a la colección perfiles_seguridad de Firestore
 *
 * Implementaciones:
 * - FirestorePerfilesRepository (producción)
 * - MockPerfilesRepository (tests)
 */
export interface IPerfilesRepository {
  /**
   * Obtiene un usuario por su UID (Firebase)
   * @param uid - UID del usuario a buscar
   * @returns Usuario con roles y permisos
   * @throws {NotFoundError} Si el usuario no existe en Firestore
   */
  obtenerPorUid(uid: string): Promise<Usuario>;

  /**
   * Obtiene un usuario por email
   * @param email - Email del usuario
   * @returns Usuario si existe
   * @throws {NotFoundError} Si no hay usuario con ese email
   */
  obtenerPorEmail(email: string): Promise<Usuario>;

  /**
   * Crea un nuevo perfil de usuario (HU-04: Registro de nuevos empleados)
   * @param usuario - Usuario a persistir
   * @returns Usuario creado
   */
  crear(usuario: Usuario): Promise<Usuario>;

  /**
   * Actualiza los permisos de un usuario
   * @param uid - UID del usuario
   * @param permisos - Nuevo array de permisos
   * @returns Usuario actualizado
   */
  actualizarPermisos(uid: string, permisos: string[]): Promise<Usuario>;

  /**
   * Desactiva un usuario (HU-05: Revocación de acceso)
   * @param uid - UID del usuario
   * @returns Usuario actualizado (con activo=false)
   */
  desactivar(uid: string): Promise<Usuario>;

  /**
   * Activa un usuario previamente desactivado
   * @param uid - UID del usuario
   * @returns Usuario actualizado (con activo=true)
   */
  activar(uid: string): Promise<Usuario>;
}
