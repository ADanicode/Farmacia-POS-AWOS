import 'package:flutter/material.dart';

/// Pantalla para usuarios con acceso pendiente de aprobación.
class PendingApprovalPage extends StatelessWidget {
  /// Constructor por defecto.
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFE6F7F2), Color(0xFFF7FCFA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 8,
              shadowColor: const Color(0x220D3B66),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1EBE8)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.pending_actions,
                      size: 64,
                      color: Color(0xFF0F9D8A),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Acceso pendiente',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu cuenta ha sido registrada en el sistema. '
                      'Espera a que un Administrador asigne tus permisos y active tu acceso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Simple logout - just navigate back to login
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (Route<dynamic> route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Salir'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
