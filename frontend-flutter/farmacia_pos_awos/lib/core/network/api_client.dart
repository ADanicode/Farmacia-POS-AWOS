import 'dart:io';

import 'package:dio/dio.dart';

/// Cliente HTTP singleton para la aplicaci�n de POS.
///
/// Provee interceptores comunes y manejo global de errores para resiliencia.
class ApiClient {
  /// Instancia �nica del cliente HTTP.
  static final ApiClient _instance = ApiClient._internal();

  /// PATR�N: SINGLETON
  factory ApiClient() {
    return _instance;
  }

  /// Constructor interno usado por el singleton.
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:3000/api/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Authorization'] = 'Bearer token_simulado_1234';
          options.headers['X-API-KEY'] = 'mi_llave_secreta';
          handler.next(options);
        },
        onError: (error, handler) {
          if (error is DioException) {
            // Manejo global de errores DioException
            if (error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout) {
              // No hay setter error en DioException 5.x; solo registrar/propagar.
              // ignore: avoid_print
              print('Error de conexión: timeout de red');
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;

  /// Retorna la instancia de Dio usada internamente.
  Dio get client => _dio;

  /// Realiza una petici�n GET con manejo global de errores.
  ///
  /// Retorna la respuesta de Dio si es exitosa.
  Future<Response> get(String path) async {
    try {
      return await _dio.get(path);
    } on DioException catch (e) {
      throw Exception('Error HTTP: ${e.message}');
    } on SocketException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }
}
