/**
 * @fileoverview Implementación del repositorio de Perfiles en Firestore
 * Accede a la colección perfiles_seguridad para obtener roles y permisos
 * Esta es la implementación del puerto IPerfilesRepository
 */

import * as admin from 'firebase-admin';
import { Usuario, RoleType, PermissionType } from '@domain/entities';
import { IPerfilesRepository } from '@application/interfaces/IPerfilesRepository';
import { FIRESTORE_COLLECTIONS } from '@config/firebase.config';

/**
 * Estructura de un documento de perfil en Firestore
 */
interface FirestorePerfil {
  uid: string;
  email: string;
  nombre: string;
  role: RoleType;
  permisos: string[];
  activo: boolean;
  fechaCreacion: admin.firestore.Timestamp;
  fechaActualizacion?: admin.firestore.Timestamp;
}

/**
 * Implementación de IPerfilesRepository usando Firestore
 * Responsabilidades:
 * 1. Crear documentos de perfil para usuarios
 * 2. Consultar perfiles por UID o email
 * 3. Actualizar permisos y estado de usuarios
 * 4. Desactivar/Activar usuarios (HU-05)
 */
export class FirestorePerfilesRepository implements IPerfilesRepository {
  private readonly collectionName = FIRESTORE_COLLECTIONS.PERFILES;

  /**
   * Constructor con inyección de dependencias
   * @param firestore - Instancia de Firestore
   */
  constructor(private readonly firestore: admin.firestore.Firestore) {}

  /**
   * Obtiene un usuario por su UID (Firebase)
   * @param uid - UID del usuario
   * @returns Usuario con roles y permisos
   * @throws {NotFoundError} Si el usuario no existe
   */
  public async obtenerPorUid(uid: string): Promise<Usuario> {
    const doc = await this.firestore
      .collection(this.collectionName)
      .doc(uid)
      .get();

    if (!doc.exists) {
      throw new Error(`Usuario ${uid} no encontrado en Firestore`);
    }

    return this.mapearDocumentoAUsuario(doc.data() as FirestorePerfil);
  }

  /**
   * Obtiene un usuario por email (útil para búsquedas)
   * @param email - Email del usuario
   * @returns Usuario con roles y permisos
   * @throws {NotFoundError} Si no hay usuario con ese email
   */
  public async obtenerPorEmail(email: string): Promise<Usuario> {
    const snapshot = await this.firestore
      .collection(this.collectionName)
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snapshot.empty) {
      throw new Error(`Usuario con email ${email} no encontrado`);
    }

    const doc = snapshot.docs[0];
    return this.mapearDocumentoAUsuario(doc.data() as FirestorePerfil);
  }

  /**
   * Crea un nuevo perfil de usuario (HU-04: Registro de Nuevos Empleados)
   * @param usuario - Usuario a persistir
   * @returns Usuario creado
   */
  public async crear(usuario: Usuario): Promise<Usuario> {
    const perfil: FirestorePerfil = {
      uid: usuario.getId(),
      email: usuario.getEmail(),
      nombre: usuario.getNombre(),
      role: usuario.getRole(),
      permisos: usuario.getPermisos(),
      activo: usuario.isActivo(),
      fechaCreacion: admin.firestore.Timestamp.now(),
    };

    await this.firestore
      .collection(this.collectionName)
      .doc(usuario.getId())
      .set(perfil);

    return usuario;
  }

  /**
   * Actualiza los permisos de un usuario
   * @param uid - UID del usuario
   * @param permisos - Nuevo array de permisos
   * @returns Usuario actualizado
   */
  public async actualizarPermisos(
    uid: string,
    permisos: string[],
  ): Promise<Usuario> {
    const usuarioActual = await this.obtenerPorUid(uid);

    await this.firestore
      .collection(this.collectionName)
      .doc(uid)
      .update({
        permisos,
        fechaActualizacion: admin.firestore.Timestamp.now(),
      });

    return Usuario.desdeFirestore({
      ...usuarioActual.toJSON(),
      permisos,
    });
  }

  /**
   * Desactiva un usuario (HU-05: Revocación inmediata de acceso a exempleados)
   * Impide que el usuario inicie sesión o realice operaciones
   *
   * @param uid - UID del usuario
   * @returns Usuario actualizado
   */
  public async desactivar(uid: string): Promise<Usuario> {
    const usuarioActual = await this.obtenerPorUid(uid);

    await this.firestore
      .collection(this.collectionName)
      .doc(uid)
      .update({
        activo: false,
        fechaActualizacion: admin.firestore.Timestamp.now(),
      });

    return Usuario.desdeFirestore({
      ...usuarioActual.toJSON(),
      activo: false,
    });
  }

  /**
   * Activa un usuario previamente desactivado
   * @param uid - UID del usuario
   * @returns Usuario actualizado
   */
  public async activar(uid: string): Promise<Usuario> {
    const usuarioActual = await this.obtenerPorUid(uid);

    await this.firestore
      .collection(this.collectionName)
      .doc(uid)
      .update({
        activo: true,
        fechaActualizacion: admin.firestore.Timestamp.now(),
      });

    return Usuario.desdeFirestore({
      ...usuarioActual.toJSON(),
      activo: true,
    });
  }

  /**
   * Mapea un documento de Firestore a entidad Usuario
   * @param doc - Documento de Firestore
   * @returns Instancia de Usuario
   */
  private mapearDocumentoAUsuario(doc: FirestorePerfil): Usuario {
    return Usuario.desdeFirestore({
      id: doc.uid,
      email: doc.email,
      nombre: doc.nombre,
      role: doc.role,
      permisos: doc.permisos as PermissionType[],
      activo: doc.activo,
      fechaCreacion: doc.fechaCreacion.toDate().toISOString(),
    });
  }
}
