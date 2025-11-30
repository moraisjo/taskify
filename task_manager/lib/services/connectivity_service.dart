import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

/// Serviço simples para monitorar conectividade e expor um stream de online/offline.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();

  /// Stream de estado online (true) / offline (false)
  Stream<bool> get onlineStream => _onlineController.stream;

  /// Último estado conhecido
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<dynamic>? _subscription;

  Future<void> initialize() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      final initialResults = _normalizeResults(initial);
      _isOnline = _mapResultsToOnline(initialResults);
      _onlineController.add(_isOnline);

      // Ouvinte contínuo
      _subscription = _connectivity.onConnectivityChanged.listen((event) {
        final results = _normalizeResults(event);
        final online = _mapResultsToOnline(results);
        if (online != _isOnline) {
          _isOnline = online;
          _onlineController.add(_isOnline);
        }
      });
    } on MissingPluginException {
      // Plugin não disponível no target (ex.: desktop sem suporte)
      _isOnline = true;
      _onlineController.add(_isOnline);
    } catch (_) {
      // Em caso de erro inesperado, assume online para não quebrar o app
      _isOnline = true;
      _onlineController.add(_isOnline);
    }
  }

  Iterable<ConnectivityResult> _normalizeResults(dynamic input) {
    if (input is Iterable<ConnectivityResult>) {
      return input;
    }
    if (input is ConnectivityResult) {
      return [input];
    }
    return const <ConnectivityResult>[];
  }

  bool _mapSingleResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.mobile:
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.vpn:
        return true;
      case ConnectivityResult.other:
        return false;
      case ConnectivityResult.none:
      case ConnectivityResult.bluetooth:
        // bluetooth aqui não garante internet
        return false;
    }
  }

  bool _mapResultsToOnline(Iterable<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any(_mapSingleResult);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _onlineController.close();
  }
}
