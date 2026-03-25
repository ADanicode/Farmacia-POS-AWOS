import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Pantalla de login para acceso al POS.
class LoginPage extends StatefulWidget {
  /// Constructor por defecto de pantalla de login.
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// Estado local de la pantalla de login.
class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFE7F7F3),
              Color(0xFFD4ECE7),
              Color(0xFFF4FAF8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: BlocConsumer<AuthBloc, AuthState>(
                listenWhen: (AuthState previous, AuthState current) =>
                    previous.errorMessage != current.errorMessage,
                listener: (BuildContext context, AuthState state) {
                  if (state.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.errorMessage!)),
                    );
                  }
                },
                builder: (BuildContext context, AuthState state) {
                  return Card(
                    elevation: 8,
                    shadowColor: const Color(0x220D3B66),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE1EBE8)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                                'Ingreso POS Farmacia',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0D3B66),
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 350.ms)
                              .slideY(begin: 0.18, duration: 350.ms),
                          const SizedBox(height: 8),
                          const Text(
                                'Accede con tu cuenta corporativa de Google.',
                              )
                              .animate(delay: 70.ms)
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.16, duration: 300.ms),
                          const SizedBox(height: 24),
                          SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        const WidgetStatePropertyAll<Color>(
                                          Colors.white,
                                        ),
                                    foregroundColor:
                                        WidgetStatePropertyAll<Color>(
                                          Colors.grey.shade800,
                                        ),
                                    overlayColor:
                                        WidgetStateProperty.resolveWith<Color?>(
                                          (Set<WidgetState> states) {
                                            if (states.contains(
                                              WidgetState.hovered,
                                            )) {
                                              return Colors.grey.shade100;
                                            }
                                            return Colors.transparent;
                                          },
                                        ),
                                    side: WidgetStatePropertyAll<BorderSide>(
                                      BorderSide(color: Colors.grey.shade300),
                                    ),
                                    shape:
                                        WidgetStatePropertyAll<
                                          RoundedRectangleBorder
                                        >(
                                          RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                    padding:
                                        const WidgetStatePropertyAll<
                                          EdgeInsetsGeometry
                                        >(
                                          EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                        ),
                                  ),
                                  icon: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4285F4),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  label: const Text('Ingresar con Google'),
                                  onPressed: () {
                                    if (state.status ==
                                        AuthStatus.authenticating) {
                                      return;
                                    }
                                    context.read<AuthBloc>().add(
                                      const AuthGoogleSignInRequested(),
                                    );
                                  },
                                ),
                              )
                              .animate(delay: 120.ms)
                              .fadeIn(duration: 320.ms)
                              .slideY(begin: 0.14, duration: 320.ms),
                          if (state.status ==
                              AuthStatus.authenticating) ...<Widget>[
                            const SizedBox(height: 12),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Autenticando con Node...'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
