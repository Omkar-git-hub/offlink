import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/lifecycle/method_channel_background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelBackgroundService', () {
    const channelName = 'com.example.offlink/background_service';
    final List<MethodCall> log = <MethodCall>[];
    bool returnError = false;
    bool isRunningResponse = true;

    setUp(() {
      log.clear();
      returnError = false;
      isRunningResponse = true;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), (
            call,
          ) async {
            log.add(call);
            if (returnError) {
              throw PlatformException(code: 'ERROR', message: 'Failed');
            }
            if (call.method == 'startForegroundService') {
              return true;
            }
            if (call.method == 'stopForegroundService') {
              return true;
            }
            if (call.method == 'isServiceRunning') {
              return isRunningResponse;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), null);
    });

    test('startService invokes channel with parameters', () async {
      final service = MethodChannelBackgroundService();
      final result = await service.startService(
        title: 'Custom Title',
        message: 'Custom Message',
      );

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, equals('startForegroundService'));
      expect(
        log.first.arguments,
        equals({'title': 'Custom Title', 'message': 'Custom Message'}),
      );
    });

    test('stopService invokes stopForegroundService', () async {
      final service = MethodChannelBackgroundService();
      final result = await service.stopService();

      expect(result, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, equals('stopForegroundService'));
    });

    test('isServiceRunning queries service state', () async {
      final service = MethodChannelBackgroundService();
      final result = await service.isServiceRunning();

      expect(result, isTrue);
      expect(log.first.method, equals('isServiceRunning'));
    });

    test('gracefully handles platform exceptions returning false', () async {
      returnError = true;
      final service = MethodChannelBackgroundService();

      expect(await service.startService(), isFalse);
      expect(await service.stopService(), isFalse);
      expect(await service.isServiceRunning(), isFalse);
    });
  });
}
