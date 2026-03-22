import 'package:equatable/equatable.dart';

/// Eventos del flujo de autenticación de la app.
sealed class AuthEvent extends Equatable {
  /// Constructor base de eventos de autenticación.
  const AuthEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Solicita el inicio de sesión con Google SSO.
class AuthGoogleSignInRequested extends AuthEvent {
  /// Constructor del evento de inicio de sesión SSO.
  const AuthGoogleSignInRequested();
}

/// Solicita el cierre de sesión de la app.
class AuthLogoutRequested extends AuthEvent {
  /// Constructor del evento de cierre de sesión.
  const AuthLogoutRequested();
}