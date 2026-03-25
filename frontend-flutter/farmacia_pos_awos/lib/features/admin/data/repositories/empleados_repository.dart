import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/empleado_perfil.dart';

/// Permisos disponibles en el sistema.
const List<String> permisosDisponibles = <String>[
  'crear_venta',
  'ver_inventario',
  'gestionar_usuarios',
  'ver_reportes_globales',
  'anular_venta',
];

/// Repositorio Firestore para gestión de perfiles de seguridad.
class EmpleadosRepository {
  /// Colección base de seguridad para empleados.
  static const String _collectionName = 'perfiles_seguridad';

  /// Instancia de Firestore.
  final FirebaseFirestore _firestore;

  /// Constructor principal con inyección de Firestore.
  EmpleadosRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection(_collectionName);
  }

  /// Stream en tiempo real de empleados para administración.
  Stream<List<EmpleadoPerfil>> streamEmpleados() {
    return _collection.orderBy('nombre').snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      return snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                EmpleadoPerfil.fromMap(doc.data(), doc.id),
          )
          .toList(growable: false);
    });
  }

  /// Crea un documento cascarón para un usuario que se loguea por primera vez (JIT).
  Future<void> crearProfilPendiente({
    required String uid,
    required String email,
    required String nombre,
  }) async {
    await _collection.doc(uid).set(<String, dynamic>{
      'uid': uid,
      'email': email.toLowerCase(),
      'nombre': nombre.trim().isNotEmpty ? nombre : email.split('@').first,
      'role': 'sin_rol',
      'activo': false,
      'permisos': <String>[],
    });
  }

  /// Actualiza un perfil existente con rol y permisos seleccionados.
  Future<void> actualizarPerfil({
    required String uid,
    required String role,
    required List<String> permisos,
    required bool activo,
  }) async {
    final String normalizedRole = role.trim().toLowerCase();
    if (normalizedRole != 'admin' &&
        normalizedRole != 'vendedor' &&
        normalizedRole != 'sin_rol') {
      throw ArgumentError('Role debe ser "admin", "vendedor" o "sin_rol".');
    }

    await _collection.doc(uid).update(<String, dynamic>{
      'role': normalizedRole,
      'permisos': permisos,
      'activo': activo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Revoca o restablece acceso del empleado sin cambiar permisos.
  Future<void> actualizarEstadoAcceso({
    required String uid,
    required bool activo,
  }) async {
    await _collection.doc(uid).update(<String, dynamic>{
      'activo': activo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina un perfil de empleado permanentemente.
  Future<void> eliminarPerfil({required String uid}) async {
    await _collection.doc(uid).delete();
  }
}
