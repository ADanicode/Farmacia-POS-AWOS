import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../domain/entities/auth_session.dart';

/// Repositorio de autenticación para backend Node.
class AuthRepository {
  /// Endpoint de login en backend Node.
  static const String _loginEndpoint = 'http://localhost:3000/api/auth/login';

  /// Endpoint para inspección de usuario actual.
  static const String _meEndpoint = 'http://localhost:3000/api/auth/me';

  /// Endpoint de cierre de sesión.
  static const String _logoutEndpoint = 'http://localhost:3000/api/auth/logout';

  /// Cliente HTTP compartido del frontend.
  final ApiClient _apiClient;

  /// Instancia de Firestore para aprovisionamiento JIT.
  final FirebaseFirestore _firestore;

  /// Constructor principal del repositorio de autenticación.
  AuthRepository({
    required ApiClient apiClient,
    required FirebaseFirestore firestore,
  }) : _apiClient = apiClient,
       _firestore = firestore;

  // CUMPLE HU-01: INICIO DE SESION SEGURO VIA BACKEND NODE.
  // PATRON: REPOSITORY - abstrae integración HTTP y mapeo de sesión.
  /// Inicia sesión enviando idToken de Google al backend.
  /// Si falla porque el usuario no existe, crea un documento cascarón en Firestore.
  Future<({AuthSession? session, bool isPending})> loginConIdToken(
    String idToken, {
    required String uid,
    required String email,
    required String displayName,
  }) async {
    try {
      final response = await _apiClient.post(
        _loginEndpoint,
        data: <String, dynamic>{'idToken': idToken},
        requiresAuth: false,
      );

      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      final Map<String, dynamic> data = body['data'] as Map<String, dynamic>;

      final String token = (data['token'] as String?) ?? '';
      AuthTokenStore().setToken(token);

      return (session: _buildSessionFromData(data, token), isPending: false);
    } catch (e) {
      final String errorMsg = e.toString();
      // Si el usuario no existe en Node, crear documento cascarón en Firestore.
      if (errorMsg.contains('Usuario no existe') ||
          errorMsg.contains('not found') ||
          errorMsg.contains('404')) {
        await _crearProfilPendiente(uid, email, displayName);
        return (
          session: AuthSession(
            token: 'pending',
            uid: uid,
            email: email,
            nombre: displayName,
            role: 'vendedor',
            permisos: const <String>[],
          ),
          isPending: true,
        );
      }
      rethrow;
    }
  }

  /// Construye una sesión validando un JWT ya emitido previamente.
  Future<AuthSession> loginConJwtExistente(String jwt) async {
    AuthTokenStore().setToken(jwt);

    final response = await _apiClient.get(_meEndpoint, requiresAuth: true);

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    final Map<String, dynamic> data = body['data'] as Map<String, dynamic>;

    return AuthSession(
      token: jwt,
      uid: (data['uid'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      nombre: (data['nombre'] as String?) ?? '',
      role: ((data['role'] as String?) ?? 'vendedor').toLowerCase(),
      permisos: ((data['permisos'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic permiso) => permiso as String)
          .toList(growable: false),
    );
  }

  // CUMPLE HU-02: CIERRE DE SESION Y LIMPIEZA INMEDIATA DE ESTADO.
  /// Cierra sesión en backend y limpia token local.
  Future<void> logout() async {
    try {
      await _apiClient.post(_logoutEndpoint, requiresAuth: true);
    } finally {
      AuthTokenStore().clear();
    }
  }

  /// Crea un documento cascarón en perfiles_seguridad para JIT.
  Future<void> _crearProfilPendiente(
    String uid,
    String email,
    String displayName,
  ) async {
    await _firestore
        .collection('perfiles_seguridad')
        .doc(uid)
        .set(<String, dynamic>{
          'uid': uid,
          'nombre': displayName.trim().isNotEmpty
              ? displayName
              : email.split('@').first,
          'email': email.toLowerCase(),
          'role': 'vendedor',
          'permisos': <String>[],
          'activo': false,
          'estado': 'pendiente',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Crea entidad de sesión a partir de respuesta de login.
  AuthSession _buildSessionFromData(Map<String, dynamic> data, String token) {
    final Map<String, dynamic> usuario =
        (data['usuario'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return AuthSession(
      token: token,
      uid: (usuario['uid'] as String?) ?? '',
      email: (usuario['email'] as String?) ?? '',
      nombre: (usuario['nombre'] as String?) ?? '',
      role: ((usuario['role'] as String?) ?? 'vendedor').toLowerCase(),
      permisos: ((data['permisos'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic permiso) => permiso as String)
          .toList(growable: false),
    );
  }
}
