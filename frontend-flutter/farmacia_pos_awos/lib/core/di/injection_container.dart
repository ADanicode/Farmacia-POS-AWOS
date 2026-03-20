import 'package:get_it/get_it.dart';

import '../network/api_client.dart';

/// Contenedor de inyección de dependencias usando GetIt.
final sl = GetIt.instance;

/// Inicializa los servicios y dependencias de la aplicación.
Future<void> init() async {
  // PATRÓN INYECCIÓN DE DEPENDENCIAS
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
}
