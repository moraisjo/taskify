import 'package:flutter/foundation.dart';

/// Configuração de API sensível à plataforma.
///
/// - Web/desktop usam localhost.
/// - Emulador Android usa 10.0.2.2 para enxergar o host.
/// - Device físico: defina via `--dart-define API_BASE_URL=http://192.168.x.x:3000/api`.
class ApiConfig {
  static const String _manualBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_manualBaseUrl.isNotEmpty) return _normalize(_manualBaseUrl);

    if (kIsWeb) return _normalize('http://localhost:3000/api');

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _normalize('http://10.0.2.2:3000/api');
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return _normalize('http://localhost:3000/api');
      case TargetPlatform.fuchsia:
        return _normalize('http://localhost:3000/api');
    }
  }

  static String _normalize(String value) {
    // Garante /api no final e sem barra dupla.
    final trimmed = value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
  }
}
