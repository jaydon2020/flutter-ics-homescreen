import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:protos/radio_api.dart' show GrpcError, StatusCode;

bool serviceUnavailable(Object error) =>
    error is GrpcError && error.code == StatusCode.unavailable;

/// Retries connection setup, never the user's failed write or control command.
class ServiceRetry {
  ServiceRetry(this.name, this.hostname, this.port);

  final String name;
  final String hostname;
  final int port;
  Timer? _timer;
  int _delaySeconds = 1;
  bool _unavailable = false;
  bool _disposed = false;

  void failed(Object error, void Function() reconnect) {
    if (_disposed) return;
    if (!serviceUnavailable(error)) {
      debugPrint('$name at $hostname:$port: $error');
      return;
    }
    if (!_unavailable) {
      debugPrint(
        '$name unavailable at $hostname:$port; retrying connection. '
        'Check that the service is running and this endpoint is correct.',
      );
      _unavailable = true;
    }
    if (_timer != null) return;
    _timer = Timer(Duration(seconds: _delaySeconds), () {
      _timer = null;
      if (!_disposed) reconnect();
    });
    _delaySeconds = (_delaySeconds * 2).clamp(1, 30);
  }

  void recovered() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    _delaySeconds = 1;
    if (_unavailable) debugPrint('$name connected at $hostname:$port');
    _unavailable = false;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
