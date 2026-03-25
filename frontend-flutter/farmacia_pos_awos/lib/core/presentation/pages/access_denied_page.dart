import 'package:flutter/material.dart';

/// Pantalla de denegación de acceso para rutas protegidas.
///
/// Mostrada cuando un usuario sin los permisos requeridos intenta navegar
/// a una ruta restringida, ya sea desde un botón de UI o directamente
/// mediante URL en Flutter Web. Cumple blindaje HU-03.
class AccessDeniedPage extends StatelessWidget {
  /// Constructor por defecto.
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso Denegado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Acceso Denegado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No tienes los permisos necesarios para acceder a esta sección.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
