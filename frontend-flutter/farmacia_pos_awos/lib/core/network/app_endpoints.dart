import 'package:flutter/foundation.dart';

/// Endpoints centrales para ambiente local y producción.
///
/// Permite definir URLs en build-time con:
/// --dart-define=NODE_API_URL=https://...
/// --dart-define=PYTHON_API_URL=https://...
abstract class AppEndpoints {
  static const String _nodeApiFromEnv = String.fromEnvironment('NODE_API_URL');
  static const String _pythonApiFromEnv = String.fromEnvironment(
    'PYTHON_API_URL',
  );

  static String get nodeBase {
    if (_nodeApiFromEnv.trim().isNotEmpty) {
      return _normalizeBaseUrl(_nodeApiFromEnv);
    }
    if (kReleaseMode) {
      return 'https://backend-node-production-2803.up.railway.app';
    }
    return 'http://localhost:3000';
  }

  static String get pythonBase {
    if (_pythonApiFromEnv.trim().isNotEmpty) {
      return _normalizeBaseUrl(_pythonApiFromEnv);
    }
    return 'http://localhost:8000';
  }

  static String get nodeApi => '$nodeBase/api';
  static String get nodeApiV1 => '$nodeBase/api/v1';
  static String get pythonApiV1 => '$pythonBase/api/v1';

  static String _normalizeBaseUrl(String value) {
    String result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
