import 'dart:io';

import 'package:dio/dio.dart';

import 'app_endpoints.dart';
import 'auth_token_store.dart';

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
        baseUrl: AppEndpoints.nodeApiV1,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final bool requiresAuth =
              (options.extra['requiresAuth'] as bool?) ?? true;
          final String? token = AuthTokenStore().token;

          if (requiresAuth && token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          options.headers['X-API-KEY'] = 'mi_llave_secreta';
          handler.next(options);
        },
        onError: (error, handler) {
          // Manejo global de errores DioException
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            // No hay setter error en DioException 5.x; solo registrar/propagar.
            // ignore: avoid_print
            print('Error de conexión: timeout de red');
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
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(
          extra: <String, dynamic>{'requiresAuth': requiresAuth},
        ),
      );
    } on DioException catch (e) {
      throw Exception(_buildHttpErrorMessage(e));
    } on SocketException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Realiza una petición POST con manejo global de errores.
  ///
  /// Retorna la respuesta de Dio si es exitosa.
  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          extra: <String, dynamic>{'requiresAuth': requiresAuth},
        ),
      );
    } on DioException catch (e) {
      throw Exception(_buildHttpErrorMessage(e));
    } on SocketException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Realiza una petición PATCH con manejo global de errores.
  ///
  /// Retorna la respuesta de Dio si es exitosa.
  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          extra: <String, dynamic>{'requiresAuth': requiresAuth},
        ),
      );
    } on DioException catch (e) {
      throw Exception(_buildHttpErrorMessage(e));
    } on SocketException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Construye un mensaje de error HTTP con detalle de backend cuando existe.
  String _buildHttpErrorMessage(DioException error) {
    final int? statusCode = error.response?.statusCode;
    final dynamic data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final String backendError =
          (data['error'] as String?) ?? (data['detail'] as String?) ?? '';
      final dynamic details = data['details'];

      if (backendError.isNotEmpty && details != null) {
        return 'HTTP $statusCode: $backendError - $details';
      }
      if (backendError.isNotEmpty) {
        return 'HTTP $statusCode: $backendError';
      }
    }

    return 'HTTP $statusCode: ${error.message}';
  }
}
