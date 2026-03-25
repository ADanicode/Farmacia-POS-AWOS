import 'package:firebase_core/firebase_core.dart';

/// Opciones de Firebase para la app web del POS.
class FirebaseWebOptions {
  /// Configuración actual de Firebase Web para este proyecto.
  static FirebaseOptions get currentPlatform {
    // CUMPLE HU-01: configuración oficial de la app web registrada en Firebase.
    return const FirebaseOptions(
      apiKey: 'AIzaSyAEP-seuC855VxRpCXhsvpbCC78B_1fubg',
      appId: '1:888412294693:web:5672b1c331fd4b16e439cc',
      messagingSenderId: '888412294693',
      projectId: 'tequeremosbien-37f64',
      authDomain: 'tequeremosbien-37f64.firebaseapp.com',
      storageBucket: 'tequeremosbien-37f64.firebasestorage.app',
      measurementId: 'G-GJXN5B5CC1',
    );
  }
}
