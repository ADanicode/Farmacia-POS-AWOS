import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/admin/presentation/pages/empleados_page.dart';
import '../../features/almacen/presentation/pages/recepcion_lotes_page.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/catalogo_admin/presentation/pages/catalogo_admin_page.dart';
import '../../features/reportes/presentation/pages/reportes_page.dart';
import '../presentation/pages/access_denied_page.dart';
import 'route_guards.dart';

/// Nombres de ruta centralizados de la aplicación.
///
/// Usar estas constantes en todas las llamadas a [Navigator.pushNamed]
/// para evitar strings duplicados y garantizar consistencia.
abstract class AppRoutes {
  /// Ruta del módulo de reportes financieros.
  static const String reportes = '/reportes';

  /// Ruta del panel de gestión de empleados.
  static const String empleados = '/empleados';

  /// Ruta de recepción de lotes de almacén.
  static const String almacen = '/almacen';

  /// Ruta del panel de administración del catálogo.
  static const String catalogo = '/catalogo';
}

/// Generador de rutas con guardias de autorización integrados.
///
/// Implementa el patrón Route Guard para Flutter Web (HU-03):
/// cada ruta protegida verifica los permisos del usuario en tiempo de
/// construcción del widget. Si el usuario navega directamente a una URL
/// restringida (ej. /reportes), el guardia intercepta la navegación y
/// muestra [AccessDeniedPage] en lugar de la pantalla solicitada.
///
/// Para activar, registrar en [MaterialApp.onGenerateRoute]:
/// ```dart
/// MaterialApp(onGenerateRoute: AppRouter.onGenerateRoute)
/// ```
abstract class AppRouter {
  /// Genera la ruta correspondiente al nombre solicitado aplicando guardias.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (BuildContext context) {
        final AuthSession? session = context.read<AuthBloc>().state.session;

        if (session == null) {
          return const AccessDeniedPage();
        }

        return switch (settings.name) {
          AppRoutes.reportes =>
            RouteGuards.puedeVerReportes(session)
                ? ReportesPage(session: session)
                : const AccessDeniedPage(),
          AppRoutes.empleados =>
            RouteGuards.esAdmin(session)
                ? const EmpleadosPage()
                : const AccessDeniedPage(),
          AppRoutes.almacen =>
            RouteGuards.esAdmin(session)
                ? const RecepcionLotesPage()
                : const AccessDeniedPage(),
          AppRoutes.catalogo =>
            RouteGuards.esAdmin(session)
                ? const CatalogoAdminPage()
                : const AccessDeniedPage(),
          _ => const AccessDeniedPage(),
        };
      },
    );
  }
}
