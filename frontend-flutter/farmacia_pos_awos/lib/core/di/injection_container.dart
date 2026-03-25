import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/admin/data/repositories/empleados_repository.dart';
import '../../features/almacen/data/repositories/almacen_repository.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/catalogo_admin/data/repositories/catalogo_admin_repository.dart';
import '../../features/catalogo_admin/presentation/cubit/catalogo_admin_cubit.dart';
import '../../features/pos/data/repositories/catalogo_repository.dart';
import '../../features/pos/data/repositories/ventas_repository.dart';
import '../../features/pos/presentation/bloc/search/search_bloc.dart';
import '../../features/reportes/data/repositories/reportes_repository.dart';
import '../network/api_client.dart';

/// Contenedor de inyecci�n de dependencias usando GetIt.
final sl = GetIt.instance;

/// Inicializa los servicios y dependencias de la aplicaci�n.
Future<void> init() async {
  // PATR�N INYECCI�N DE DEPENDENCIAS
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);

  // PATRON: REPOSITORY - Encapsula acceso a servicios remotos por contexto.
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      apiClient: sl<ApiClient>(),
      firestore: sl<FirebaseFirestore>(),
    ),
  );
  sl.registerLazySingleton<CatalogoRepository>(
    () => CatalogoRepository(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<VentasRepository>(
    () => VentasRepository(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<ReportesRepository>(
    () => ReportesRepository(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<EmpleadosRepository>(
    () => EmpleadosRepository(firestore: sl<FirebaseFirestore>()),
  );
  sl.registerLazySingleton<AlmacenRepository>(
    () => AlmacenRepository(apiClient: sl<ApiClient>()),
  );
  sl.registerLazySingleton<CatalogoAdminRepository>(
    () => CatalogoAdminRepository(apiClient: sl<ApiClient>()),
  );

  // PATRON: BLOC - Orquesta estado de búsqueda y caja en presentación.
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl<AuthRepository>()),
  );
  sl.registerFactory<SearchBloc>(
    () => SearchBloc(catalogoRepository: sl<CatalogoRepository>()),
  );
  sl.registerFactory<CatalogoAdminCubit>(
    () => CatalogoAdminCubit(repository: sl<CatalogoAdminRepository>()),
  );
}
