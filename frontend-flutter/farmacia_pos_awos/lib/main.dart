import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection_container.dart' as di;
import 'core/firebase/firebase_web_options.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/pending_approval_page.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'features/pos/presentation/pages/pos_page.dart';

/// Punto de entrada principal para la app POS de farmacia.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(options: FirebaseWebOptions.currentPlatform);
  } else {
    await Firebase.initializeApp();
  }

  await di.init();
  runApp(const MyApp());
}

/// Widget raiz de la aplicacion.
class MyApp extends StatefulWidget {
  /// Constructor por defecto de MyApp.
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Estado raíz para tema dinámico y splash inicial.
class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
        });
      }
    });
  }

  /// Alterna entre tema claro y oscuro.
  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  /// Tema claro con branding farmacia.
  ThemeData _buildLightTheme() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F9D8A),
      primary: const Color(0xFF0F9D8A),
      secondary: const Color(0xFF0D3B66),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF3FAF8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFE6F6F2),
        foregroundColor: Color(0xFF0D3B66),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Tema oscuro con branding farmacia.
  ThemeData _buildDarkTheme() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F9D8A),
      primary: const Color(0xFF23C9AE),
      secondary: const Color(0xFF7DB8FF),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0E1A24),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF122534),
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF162A3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => di.sl<AuthBloc>(),
      child: MaterialApp(
        title: 'Farmacia AWOS POS',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: _themeMode,
        // CUMPLE HU-03: guardias de ruta activos para TODAS las rutas nombradas.
        // Cualquier navegación directa por URL en Flutter Web pasa por AppRouter,
        // que verifica permisos antes de construir la pantalla solicitada.
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (BuildContext context, AuthState state) {
            // CUMPLE TAREA 2: splash con duración de 3 segundos.
            if (_showSplash) {
              return const SplashScreen();
            }

            // CUMPLE JIT: Usuario pendiente de aprobación por admin.
            if (state.status == AuthStatus.accessPending) {
              return const PendingApprovalPage();
            }

            if (state.status == AuthStatus.authenticated &&
                state.session != null) {
              // CUMPLE HU-03: CONTROL DE ACCESO POR ROL/PERMISOS DESDE SESION.
              return PosPage(
                session: state.session!,
                isDarkMode: _themeMode == ThemeMode.dark,
                onLogout: () {
                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                },
                onToggleTheme: _toggleTheme,
              );
            }

            return const LoginPage();
          },
        ),
      ),
    );
  }
}
