import 'package:flutter/material.dart';

/// Pantalla base para recepción de lotes.
class RecepcionLotesPage extends StatelessWidget {
  /// Constructor por defecto.
  const RecepcionLotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Recepción de Lotes',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
