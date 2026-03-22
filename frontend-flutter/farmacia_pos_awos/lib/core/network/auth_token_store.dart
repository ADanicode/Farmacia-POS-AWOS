/// Store en memoria para el JWT de sesión del usuario autenticado.
class AuthTokenStore {
  /// Instancia singleton del store de token.
  static final AuthTokenStore _instance = AuthTokenStore._internal();

  /// Constructor factory para obtener el singleton.
  factory AuthTokenStore() {
    return _instance;
  }

  /// Constructor interno del singleton.
  AuthTokenStore._internal();

  String? _token;

  /// Token JWT actual de la sesión.
  String? get token => _token;

  /// Guarda o reemplaza el token JWT.
  void setToken(String token) {
    _token = token;
  }

  /// Limpia el token actual de la sesión.
  void clear() {
    _token = null;
  }
}
