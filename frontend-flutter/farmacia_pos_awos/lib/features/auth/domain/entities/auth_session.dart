import 'package:equatable/equatable.dart';

/// Entidad de sesión autenticada en el frontend.
class AuthSession extends Equatable {
  /// JWT emitido por backend Node.
  final String token;

  /// UID del usuario autenticado.
  final String uid;

  /// Correo del usuario autenticado.
  final String email;

  /// Nombre del usuario autenticado.
  final String nombre;

  /// Rol del usuario autenticado.
  final String role;

  /// Permisos efectivos del usuario autenticado.
  final List<String> permisos;

  /// Constructor principal de la sesión autenticada.
  const AuthSession({
    required this.token,
    required this.uid,
    required this.email,
    required this.nombre,
    required this.role,
    required this.permisos,
  });

  @override
  List<Object?> get props => <Object?>[
    token,
    uid,
    email,
    nombre,
    role,
    permisos,
  ];
}
