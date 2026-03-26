import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/app_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../domain/entities/auth_session.dart';

/// Repositorio de autenticación para backend Node.
class AuthRepository {
  /// Endpoint de login en backend Node.
  static String get _loginEndpoint => '${AppEndpoints.nodeApi}/auth/login';

  /// Endpoint para inspección de usuario actual.
  static String get _meEndpoint => '${AppEndpoints.nodeApi}/auth/me';

  /// Endpoint de cierre de sesión.
  static String get _logoutEndpoint => '${AppEndpoints.nodeApi}/auth/logout';

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
    final DocumentSnapshot<Map<String, dynamic>>? perfilExistente =
        await _obtenerPerfilPorUidOEmail(uid: uid, email: email);

    if (perfilExistente == null) {
      await _crearUsuarioSinRol(uid, email, displayName);
      return (
        session: AuthSession(
          token: 'pending',
          uid: uid,
          email: email,
          nombre: displayName,
          role: 'sin_rol',
          permisos: const <String>[],
        ),
        isPending: true,
      );
    }

    final Map<String, dynamic> perfilData =
        perfilExistente.data() ?? <String, dynamic>{};
    final List<String> permisosFirestore =
        ((perfilData['permisos'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic permiso) => permiso.toString())
            .toList(growable: false);

    if (!_tieneAccesoAprobado(perfilData, permisosFirestore)) {
      return (
        session: AuthSession(
          token: 'pending',
          uid: (perfilData['uid'] as String?) ?? uid,
          email: (perfilData['email'] as String?) ?? email,
          nombre: (perfilData['nombre'] as String?) ?? displayName,
          role: ((perfilData['role'] as String?) ?? 'sin_rol').toLowerCase(),
          permisos: permisosFirestore,
        ),
        isPending: true,
      );
    }

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

      final AuthSession session = _buildSessionFromData(data, token);
      return (session: session, isPending: false);
    } catch (e) {
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

  /// Crea un documento cascarón JIT sin rol ni permisos efectivos.
  Future<void> _crearUsuarioSinRol(
    String uid,
    String email,
    String displayName,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>>? perfilExistente =
        await _obtenerPerfilPorUidOEmail(uid: uid, email: email);

    if (perfilExistente != null) {
      return;
    }

    await _firestore
        .collection('perfiles_seguridad')
        .doc(uid)
        .set(<String, dynamic>{
          'uid': uid,
          'email': email.toLowerCase(),
          'nombre': displayName.trim().isNotEmpty
              ? displayName
              : email.split('@').first,
          'role': 'sin_rol',
          'activo': false,
          'permisos': <String>[],
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
  }

  /// Evalúa si el usuario tiene acceso habilitado según Firestore.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _obtenerPerfilPorUidOEmail({
    required String uid,
    required String email,
  }) async {
    final CollectionReference<Map<String, dynamic>> perfiles = _firestore
        .collection('perfiles_seguridad');

    final String emailNormalizado = email.toLowerCase();

    // Primero buscar por UID (más rápido y exacto)
    final DocumentSnapshot<Map<String, dynamic>> byUid = await perfiles
        .doc(uid)
        .get();
    if (byUid.exists) {
      return byUid;
    }

    // Luego buscar por email normalizado
    final QuerySnapshot<Map<String, dynamic>> byEmail = await perfiles
        .where('email', isEqualTo: emailNormalizado)
        .limit(1)
        .get();
    if (byEmail.docs.isNotEmpty) {
      return byEmail.docs.first;
    }

    return null;
  }

  bool _tieneAccesoAprobado(
    Map<String, dynamic> data,
    List<String> permisosSesion,
  ) {
    final bool activo = (data['activo'] as bool?) ?? false;
    final List<String> permisosFirestore =
        ((data['permisos'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic permiso) => permiso.toString())
            .toList(growable: false);

    final bool tienePermisos =
        permisosFirestore.isNotEmpty || permisosSesion.isNotEmpty;
    return activo && tienePermisos;
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
      role: ((usuario['role'] as String?) ?? 'sin_rol').toLowerCase(),
      permisos: ((data['permisos'] as List<dynamic>?) ?? <dynamic>[])
          .map((dynamic permiso) => permiso as String)
          .toList(growable: false),
    );
  }
}
