import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Pantalla de carga inicial con branding farmacia.
class SplashScreen extends StatelessWidget {
  /// Constructor por defecto de splash screen.
  const SplashScreen({super.key});

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 180,
                width: 180,
                child: Lottie.asset(
                  'assets/animations/Doctor.json',
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'FARMACIA AWOS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Cargando sistema de punto de venta...'),
            ],
          ),
        ),
      ),
    );
  }
}
