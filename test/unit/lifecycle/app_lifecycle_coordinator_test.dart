import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_discovery_event.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/connection.dart';
import 'package:offlink/bluetooth/discovery.dart';
import 'package:offlink/domain/lifecycle/app_lifecycle_coordinator.dart';
import 'package:offlink/domain/lifecycle/app_lifecycle_manager.dart';
import 'package:offlink/domain/lifecycle/background_service_contract.dart';
import 'package:offlink/domain/lifecycle/connection_recovery_coordinator.dart';
import 'package:offlink/domain/lifecycle/pending_message_recovery_service.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/messaging/message_repository.dart';

class _FakeBackgroundService implements BackgroundServiceContract {
  bool isRunning = false;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> startService({String? title, String? message}) async {
    startCalls++;
    isRunning = true;
    return true;
  }

  @override
  Future<bool> stopService() async {
    stopCalls++;
    isRunning = false;
    return true;
  }

  @override
  Future<bool> isServiceRunning() async => isRunning;
}

class _FakeDiscovery implements BleDiscovery {
  bool isScanning = false;

  @override
  Stream<BlePeer> get discoveredPeers => const Stream.empty();

  @override
  Stream<BleDiscoveryEvent> get discoveryEvents => const Stream.empty();

  @override
  Future<void> startScanning() async {
    isScanning = true;
  }

  @override
  Future<void> stopScanning() async {
    isScanning = false;
  }

  @override
  Future<void> startAdvertising() async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<Set<String>> completeScanCycle() async => const {};

  void dispose() {}
}

class _DummyConnection implements BleConnection {
  @override
  Stream<BleConnectionState> get connectionStates => const Stream.empty();
  @override
  Future<void> connect(BlePeer peer) async {}
  @override
  Future<void> disconnect(String peerId) async {}
}

class _DummyRepo implements MessageRepository {
  @override
  Future<void> saveMessage(
    ChatMessage message, {
    required String conversationId,
  }) async {}
  @override
  Future<List<ChatMessage>> getMessagesForConversation(
    String c, {
    int limit = 100,
    int offset = 0,
  }) async => [];
  @override
  Future<List<ChatMessage>> getPendingMessages({int limit = 50}) async => [];
  @override
  Future<ChatMessage?> getMessageById(String messageId) async => null;
  @override
  Future<int> pruneExpiredMessages({
    Duration maxAge = const Duration(hours: 24),
  }) async => 0;
  @override
  Future<void> updateMessageStatus(
    String messageId,
    ChatMessageStatus status,
  ) async {}
  @override
  Stream<List<ChatMessage>> watchMessagesForConversation(
    String conversationId,
  ) => const Stream.empty();
  @override
  Future<void> deleteMessagesForConversation(String conversationId) async {}
}

class _DummyMessageService implements DirectMessageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppLifecycleCoordinator', () {
    late AppLifecycleManager lifecycleManager;
    late _FakeBackgroundService backgroundService;
    late ConnectionRecoveryCoordinator connectionRecovery;
    late PendingMessageRecoveryService pendingMessageRecovery;
    late _FakeDiscovery discovery;
    late AppLifecycleCoordinator coordinator;

    setUp(() {
      lifecycleManager = AppLifecycleManager();
      backgroundService = _FakeBackgroundService();
      connectionRecovery = ConnectionRecoveryCoordinator(
        connection: _DummyConnection(),
      );
      pendingMessageRecovery = PendingMessageRecoveryService(
        messageService: _DummyMessageService(),
        messageRepository: _DummyRepo(),
      );
      discovery = _FakeDiscovery();

      coordinator = AppLifecycleCoordinator(
        lifecycleManager: lifecycleManager,
        backgroundService: backgroundService,
        connectionRecovery: connectionRecovery,
        pendingMessageRecovery: pendingMessageRecovery,
        discovery: discovery,
      );
    });

    tearDown(() {
      coordinator.dispose();
    });

    test(
      'starts foreground service and pauses aggressive scanning on backgrounding',
      () async {
        discovery.isScanning = true;

        lifecycleManager.handleLifecycleChange(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);

        expect(backgroundService.startCalls, equals(1));
        expect(coordinator.isBackgroundServiceActive, isTrue);
        expect(discovery.isScanning, isFalse);
      },
    );

    test(
      'restarts scanning and processes pending messages on resume',
      () async {
        lifecycleManager.handleLifecycleChange(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);

        lifecycleManager.handleLifecycleChange(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);

        expect(discovery.isScanning, isTrue);
      },
    );

    test('stops foreground service on detached', () async {
      lifecycleManager.handleLifecycleChange(AppLifecycleState.detached);
      await Future<void>.delayed(Duration.zero);

      expect(backgroundService.stopCalls, equals(1));
      expect(coordinator.isBackgroundServiceActive, isFalse);
    });
  });
}
