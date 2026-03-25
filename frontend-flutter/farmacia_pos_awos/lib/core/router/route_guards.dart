import '../../features/auth/domain/entities/auth_session.dart';

/// Lógica centralizada de permisos para guardias de rutas.
///
/// Desacopla las reglas de autorización de la capa de presentación, garantizando
/// que tanto la UI (botones visibles) como las rutas (navegación directa por URL
/// en Flutter Web) apliquen exactamente las mismas reglas de RBAC.
abstract class RouteGuards {
  /// Verifica si la sesión corresponde a un Administrador.
  static bool esAdmin(AuthSession session) =>
      session.role.toLowerCase() == 'admin';

  /// Verifica si el usuario puede ver reportes financieros globales.
  ///
  /// Requiere rol [admin] O permiso explícito [ver_reportes_globales].
  /// Los roles [cajero] y [vendedor] NO tienen acceso a reportes financieros
  /// globales salvo que se les asigne el permiso explícitamente.
  static bool puedeVerReportes(AuthSession session) =>
      session.role.toLowerCase() == 'admin' ||
      session.permisos.contains('ver_reportes_globales');
}
