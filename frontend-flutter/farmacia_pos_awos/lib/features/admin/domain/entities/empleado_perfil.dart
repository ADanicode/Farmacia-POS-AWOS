import 'package:equatable/equatable.dart';

/// Entidad de perfil de empleado almacenada en Firestore.
class EmpleadoPerfil extends Equatable {
  /// UID único del empleado (Firebase Auth UID).
  final String uid;

  /// Nombre del empleado.
  final String nombre;

  /// Correo del empleado.
  final String email;

  /// Rol de seguridad: "admin" o "vendedor".
  final String role;

  /// Permisos efectivos seleccionados manualmente.
  final List<String> permisos;

  /// Marca si el acceso está habilitado.
  final bool activo;

  /// Estado de aprovisionamiento: "aprobado" o "pendiente".
  final String estado;

  /// Constructor principal de perfil de empleado.
  const EmpleadoPerfil({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.role,
    required this.permisos,
    required this.activo,
    required this.estado,
  });

  /// Crea entidad desde documento de Firestore.
  factory EmpleadoPerfil.fromMap(Map<String, dynamic> map, String documentId) {
    return EmpleadoPerfil(
      uid: (map['uid'] as String?)?.trim().isNotEmpty == true
          ? (map['uid'] as String)
          : documentId,
      nombre: (map['nombre'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      role: ((map['role'] as String?) ?? 'SIN_ROL').toUpperCase(),
      permisos: ((map['permisos'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic permiso) => permiso.toString())
          .toList(growable: false),
      activo: (map['activo'] as bool?) ?? false,
      estado: (map['estado'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => <Object?>[
    uid,
    nombre,
    email,
    role,
    permisos,
    activo,
    estado,
  ];
}
