import 'package:flutter/material.dart';

/// Pantalla principal del POS de farmacia.
class PosPage extends StatelessWidget {
  /// Constructor por defecto de PosPage.
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmacia AWOS - POS'),
      ),
      body: const Center(
        child: Text('Caja registradora'),
      ),
    );
  }
}
