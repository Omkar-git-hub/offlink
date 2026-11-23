import 'package:flutter/services.dart';

import '../../domain/lifecycle/background_service_contract.dart';

class MethodChannelBackgroundService implements BackgroundServiceContract {
  MethodChannelBackgroundService({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel(
            'io.github.omkar_git_hub.offlink/background_service',
          );

  final MethodChannel _channel;

  @override
  Future<bool> startService({String? title, String? message}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startForegroundService',
        {'title': ?title, 'message': ?message},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopForegroundService');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
