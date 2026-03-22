import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_session.dart';

/// Estado del flujo de autenticación.
enum AuthStatus {
  /// Usuario no autenticado.
  unauthenticated,

  /// Proceso de autenticación en curso.
  authenticating,

  /// Usuario autenticado con sesión activa.
  authenticated,

  /// Usuario registrado pero esperando aprobación del admin.
  accessPending,

  /// Falló el proceso de autenticación.
  failure,
}

/// Estado inmutable del AuthBloc.
class AuthState extends Equatable {
  /// Estado actual de autenticación.
  final AuthStatus status;

  /// Sesión activa del usuario autenticado o pendiente.
  final AuthSession? session;

  /// Mensaje de error cuando falla autenticación.
  final String? errorMessage;

  /// Constructor principal del estado de autenticación.
  const AuthState({required this.status, this.session, this.errorMessage});

  /// Crea el estado inicial no autenticado.
  factory AuthState.initial() {
    return const AuthState(
      status: AuthStatus.unauthenticated,
      session: null,
      errorMessage: null,
    );
  }

  /// Crea una copia del estado con cambios parciales.
  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, session, errorMessage];
}
