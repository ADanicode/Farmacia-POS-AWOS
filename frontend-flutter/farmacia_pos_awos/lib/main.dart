import 'package:flutter/material.dart';
import 'core/di/injection_container.dart' as di;
import 'features/pos/presentation/pages/pos_page.dart';

/// Punto de entrada principal para la app POS de farmacia.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

/// Widget ra�z de la aplicaci�n.
class MyApp extends StatelessWidget {
  /// Constructor por defecto de MyApp.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farmacia AWOS POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const PosPage(),
    );
  }
}
