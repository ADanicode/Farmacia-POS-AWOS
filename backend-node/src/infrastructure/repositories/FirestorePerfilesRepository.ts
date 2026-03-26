import * as admin from 'firebase-admin';
import { Usuario, RoleType, PermissionType } from '@domain/entities';
import { IPerfilesRepository } from '@application/interfaces/IPerfilesRepository';
import { FIRESTORE_COLLECTIONS } from '@config/firebase.config';

interface FirestorePerfil {
  uid: string;
  email: string;
  nombre: string;
  role: RoleType;
  permisos: string[];
  activo: boolean;
  fechaCreacion?: admin.firestore.Timestamp;
  fechaActualizacion?: admin.firestore.Timestamp;
  updatedAt?: admin.firestore.Timestamp;
}

export class FirestorePerfilesRepository implements IPerfilesRepository {
  private readonly collectionName = FIRESTORE_COLLECTIONS.PERFILES;

  constructor(private readonly firestore: admin.firestore.Firestore) {}

  public async obtenerPorUid(uid: string): Promise<Usuario> {
    const doc = await this.firestore.collection(this.collectionName).doc(uid).get();
    if (!doc.exists) throw new Error(`Usuario ${uid} no encontrado`);
    return this.mapearDocumentoAUsuario(doc.data() as FirestorePerfil);
  }

  public async obtenerPorEmail(email: string): Promise<Usuario> {
    // IMPORTANTE: Normalizar email a lowercase para buscar de forma consistente
    const normalizedEmail = email.toLowerCase();
    const snapshot = await this.firestore.collection(this.collectionName)
      .where('email', '==', normalizedEmail).limit(1).get();
    if (snapshot.empty) throw new Error(`Email ${normalizedEmail} no encontrado`);
    return this.mapearDocumentoAUsuario(snapshot.docs[0].data() as FirestorePerfil);
  }

  public async crear(usuario: Usuario): Promise<Usuario> {
    const perfil: FirestorePerfil = {
      uid: usuario.getId(),
      email: usuario.getEmail().toLowerCase(),  // Normalizar a lowercase
      nombre: usuario.getNombre(),
      role: usuario.getRole(),
      permisos: usuario.getPermisos(),
      activo: usuario.isActivo(),
      fechaCreacion: admin.firestore.Timestamp.now(),
    };

    await this.firestore.collection(this.collectionName).doc(usuario.getId()).set(perfil);
    return usuario;
  }

  public async actualizarPermisos(uid: string, permisos: string[]): Promise<Usuario> {
    await this.firestore.collection(this.collectionName).doc(uid).update({
      permisos,
      fechaActualizacion: admin.firestore.Timestamp.now(),
    });
    return this.obtenerPorUid(uid);
  }

  public async desactivar(uid: string): Promise<Usuario> {
    await this.firestore.collection(this.collectionName).doc(uid).update({
      activo: false,
      fechaActualizacion: admin.firestore.Timestamp.now(),
    });
    return this.obtenerPorUid(uid);
  }

  public async activar(uid: string): Promise<Usuario> {
    await this.firestore.collection(this.collectionName).doc(uid).update({
      activo: true,
      fechaActualizacion: admin.firestore.Timestamp.now(),
    });
    return this.obtenerPorUid(uid);
  }

  private mapearDocumentoAUsuario(doc: FirestorePerfil): Usuario {
    const roleNormalizado = String(doc.role).toLowerCase();
    const permisosNormalizados = (doc.permisos ?? []).map((permiso) =>
      String(permiso).toLowerCase(),
    );
    const fecha = doc.fechaCreacion
      ? doc.fechaCreacion.toDate()
      : doc.updatedAt
      ? doc.updatedAt.toDate()
      : doc.fechaActualizacion
      ? doc.fechaActualizacion.toDate()
      : new Date();

    return Usuario.desdeFirestore({
      id: doc.uid,
      email: doc.email,
      nombre: doc.nombre,
      role: roleNormalizado,
      permisos: permisosNormalizados as PermissionType[],
      activo: doc.activo,
      fechaCreacion: fecha.toISOString(),
    });
  }
}
