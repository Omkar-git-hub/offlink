import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/core/identity/node_id_generator.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/messaging/message_repository.dart';
import 'package:offlink/domain/messaging/message_service.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/domain/security/peer_security_repository.dart';
import 'package:offlink/domain/security/trust_status.dart';
import 'package:offlink/features/chat/chat_page.dart';

import '../../unit/identity/fakes/fake_secure_key_storage.dart';

class _MockSecurityRepo implements PeerSecurityRepository {
  final Set<String> blocked = {};
  PeerTrust? trust;

  @override
  Future<void> blockPeer(String nodeId, {String reason = 'manual'}) async =>
      blocked.add(nodeId);

  @override
  Future<void> unblockPeer(String nodeId) async => blocked.remove(nodeId);

  @override
  Future<bool> isPeerBlocked(String nodeId) async => blocked.contains(nodeId);

  @override
  bool isPeerBlockedSync(String nodeId) => blocked.contains(nodeId);

  @override
  Future<List<BlockedPeer>> getBlockedPeers() async => [];

  @override
  Stream<List<BlockedPeer>> watchBlockedPeers() => const Stream.empty();

  @override
  Future<PeerTrust?> getPeerTrust(String peerNodeId) async => trust;

  @override
  Future<void> saveOrUpdatePeerTrust(PeerTrust newTrust) async {
    trust = newTrust;
  }

  @override
  Future<void> setPeerVerificationStatus(
    String peerNodeId,
    TrustStatus status,
  ) async {
    trust = trust?.copyWith(trustStatus: status);
  }
}

class MockMessageService implements MessageService {
  final StreamController<ChatMessage> _incomingController =
      StreamController<ChatMessage>.broadcast();

  final List<({String peerId, String recipientNodeId, String content})>
  sentRequests = [];

  Completer<ChatMessage>? sendCompleter;
  Object? sendError;

  @override
  Stream<ChatMessage> get incomingMessages => _incomingController.stream;

  @override
  Future<ChatMessage> sendMessage({
    required String peerId,
    required String recipientNodeId,
    required String content,
  }) async {
    sentRequests.add((
      peerId: peerId,
      recipientNodeId: recipientNodeId,
      content: content,
    ));

    if (sendError != null) {
      throw sendError!;
    }

    if (sendCompleter != null) {
      return sendCompleter!.future;
    }

    return ChatMessage(
      id: 'mock-msg-${sentRequests.length}',
      conversationId: peerId,
      senderNodeId: 'local-node',
      recipientNodeId: recipientNodeId,
      content: content,
      timestamp: DateTime.now(),
      isOutgoing: true,
      status: ChatMessageStatus.sent,
    );
  }

  void emit(ChatMessage message) {
    _incomingController.add(message);
  }

  @override
  void dispose() {
    _incomingController.close();
  }
}

class MockMessageRepository implements MessageRepository {
  final List<ChatMessage> messages = [];

  @override
  Future<void> saveMessage(
    ChatMessage message, {
    required String conversationId,
  }) async {
    messages.add(message);
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    return List.from(messages);
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    ChatMessageStatus status,
  ) async {}

  @override
  Stream<List<ChatMessage>> watchMessagesForConversation(
    String conversationId,
  ) => Stream.value(messages);

  @override
  Future<void> deleteMessagesForConversation(String conversationId) async {
    messages.clear();
  }

  @override
  Future<List<ChatMessage>> getPendingMessages({int limit = 50}) async => [];

  @override
  Future<ChatMessage?> getMessageById(String messageId) async {
    final matches = messages.where((m) => m.id == messageId);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<int> pruneExpiredMessages({
    Duration maxAge = const Duration(hours: 24),
  }) async => 0;
}

class _TestPacketTransport implements PacketTransport {
  final StreamController<OfflinkPacket> _incoming =
      StreamController<OfflinkPacket>.broadcast();

  @override
  Stream<OfflinkPacket> get incomingPackets => _incoming.stream;

  @override
  List<String> get connectedPeerIds => const [];

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {}
}

class _TestIdentityRepo implements IdentityRepository {
  _TestIdentityRepo(this.identity);
  final OfflinkIdentity identity;

  @override
  Future<OfflinkIdentity?> loadIdentity() async => identity;
  @override
  Future<bool> hasIdentity() async => true;
  @override
  Future<void> saveIdentity(OfflinkIdentity identity) async {}
  @override
  Future<void> updateUsername(String username) async {}
  @override
  Future<void> clearIdentity() async {}
}

void main() {
  group('ChatPage', () {
    late MockMessageService messageService;
    final testPeer = BlePeer(
      peerId: 'peer-bob-device-id',
      displayName: 'Bob',
      signalStrength: -65,
    );

    setUp(() {
      messageService = MockMessageService();
    });

    tearDown(() {
      messageService.dispose();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(home: child);
    }

    testWidgets('displays peer name and connected status', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChatPage(
            peer: testPeer,
            messageService: messageService,
            isConnected: true,
          ),
        ),
      );

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('No messages yet'), findsOneWidget);
    });

    testWidgets('sends message and renders outgoing chat bubble', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          ChatPage(
            peer: testPeer,
            messageService: messageService,
            isConnected: true,
          ),
        ),
      );

      final input = find.byType(TextField);
      expect(input, findsOneWidget);

      await tester.enterText(input, 'Hello Bob over BLE!');
      final sendButton = find.byTooltip('Send message');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(messageService.sentRequests, hasLength(1));
      expect(messageService.sentRequests.first.content, 'Hello Bob over BLE!');
      expect(find.text('Hello Bob over BLE!'), findsOneWidget);
      expect(find.text('No messages yet'), findsNothing);
    });

    testWidgets('prevents duplicate sends when tapped rapidly', (tester) async {
      final completer = Completer<ChatMessage>();
      messageService.sendCompleter = completer;

      await tester.pumpWidget(
        createTestApp(
          ChatPage(
            peer: testPeer,
            messageService: messageService,
            isConnected: true,
          ),
        ),
      );

      final input = find.byType(TextField);
      await tester.enterText(input, 'Testing duplicate send');

      final sendButton = find.byTooltip('Send message');
      await tester.tap(sendButton);
      await tester.pump();

      // Tap again while sending is in progress
      await tester.tap(sendButton);
      await tester.pump();

      // Only 1 send request should have been dispatched
      expect(messageService.sentRequests, hasLength(1));

      // Resolve the pending send
      completer.complete(
        ChatMessage(
          id: 'resolved-msg',
          conversationId: testPeer.peerId,
          senderNodeId: 'local-node',
          recipientNodeId: testPeer.peerId,
          content: 'Testing duplicate send',
          timestamp: DateTime.now(),
          isOutgoing: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(messageService.sentRequests, hasLength(1));
      expect(find.text('Testing duplicate send'), findsOneWidget);
    });

    testWidgets('renders incoming messages from peer', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChatPage(
            peer: testPeer,
            messageService: messageService,
            isConnected: true,
          ),
        ),
      );

      messageService.emit(
        ChatMessage(
          id: 'incoming-1',
          conversationId: testPeer.peerId,
          senderNodeId: testPeer.peerId,
          recipientNodeId: 'local-node',
          content: 'Hey Alice! Got your message.',
          timestamp: DateTime.now(),
          isOutgoing: false,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hey Alice! Got your message.'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when send fails', (tester) async {
      messageService.sendError = StateError('Peer disconnected');

      await tester.pumpWidget(
        createTestApp(
          ChatPage(
            peer: testPeer,
            messageService: messageService,
            isConnected: false,
          ),
        ),
      );

      final input = find.byType(TextField);
      await tester.enterText(input, 'Will fail');
      final sendButton = find.byTooltip('Send message');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to send message'), findsOneWidget);
    });

    testWidgets('loads and renders persisted message history on start', (
      tester,
    ) async {
      final mockRepo = MockMessageRepository();
      mockRepo.messages.addAll([
        ChatMessage(
          id: 'hist-1',
          conversationId: testPeer.peerId,
          senderNodeId: testPeer.peerId,
          recipientNodeId: 'local-node',
          content: 'Persisted incoming message',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          isOutgoing: false,
          status: ChatMessageStatus.delivered,
        ),
        ChatMessage(
          id: 'hist-2',
          conversationId: testPeer.peerId,
          senderNodeId: 'local-node',
          recipientNodeId: testPeer.peerId,
          content: 'Persisted outgoing reply',
          timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
          isOutgoing: true,
          status: ChatMessageStatus.sent,
        ),
      ]);

      await tester.pumpWidget(
        createTestApp(
          ChatPage(
            peer: testPeer,
            messageService: messageService,
            messageRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Persisted incoming message'), findsOneWidget);
      expect(find.text('Persisted outgoing reply'), findsOneWidget);
    });

    testWidgets(
      'displays Encrypted badge when DirectMessageService has active session',
      (tester) async {
        final keyService = IdentityKeyService(
          secureStorage: FakeSecureKeyStorage(),
        );
        final keyPair = await keyService.generateKeyPair();
        await keyService.storePrivateKey(keyPair.privateKey);

        final aliceIdentity = OfflinkIdentity(
          nodeId: 'node-alice',
          username: 'Alice',
          publicKey: '00' * 32,
          createdAt: DateTime.now().toUtc(),
        );

        final idManager = IdentityManager(
          repository: _TestIdentityRepo(aliceIdentity),
          initializationService: IdentityInitializationService(
            nodeIdGenerator: NodeIdGenerator(),
            keyService: keyService,
          ),
          keyService: keyService,
        );
        await idManager.loadExistingIdentity();

        final sessionService = SecureSessionService(
          identityKeyService: keyService,
          getLocalNodeId: () => 'node-alice',
        );

        final bobKeyService = IdentityKeyService(
          secureStorage: FakeSecureKeyStorage(),
        );
        final bobKeyPair = await bobKeyService.generateKeyPair();
        await bobKeyService.storePrivateKey(bobKeyPair.privateKey);
        final bobSessionService = SecureSessionService(
          identityKeyService: bobKeyService,
          getLocalNodeId: () => testPeer.peerId,
        );

        final initPayload = await sessionService.createHandshakeInit(
          testPeer.peerId,
        );
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
        );
        await sessionService.handleHandshakeResponse(responsePayload);

        final directService = DirectMessageService(
          packetTransport: _TestPacketTransport(),
          identityManager: idManager,
          secureSessionService: sessionService,
        );

        expect(directService.hasSecureSession(testPeer.peerId), isTrue);

        await tester.pumpWidget(
          createTestApp(
            ChatPage(
              peer: testPeer,
              messageService: directService,
              isConnected: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Encrypted'), findsOneWidget);
        expect(find.byIcon(Icons.lock), findsOneWidget);

        directService.dispose();
      },
    );

    testWidgets(
      'ChatPage displays security menu and handles peer blocking flow',
      (tester) async {
        final mockRepo = _MockSecurityRepo();

        await tester.pumpWidget(
          createTestApp(
            ChatPage(
              peer: testPeer,
              messageService: messageService,
              securityRepository: mockRepo,
              isConnected: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Shield icon is displayed
        final shieldButton = find.byIcon(Icons.shield_outlined);
        expect(shieldButton, findsOneWidget);

        // 2. Open security popup menu
        await tester.tap(shieldButton);
        await tester.pumpAndSettle();

        expect(find.text('Safety Fingerprint'), findsOneWidget);
        expect(find.text('Block Peer'), findsOneWidget);

        // 3. Tap Block Peer -> opens confirmation dialog
        await tester.tap(find.text('Block Peer'));
        await tester.pumpAndSettle();

        expect(find.text('Block Bob?'), findsOneWidget);
        expect(
          find.textContaining('You will no longer receive messages'),
          findsOneWidget,
        );

        // 4. Confirm blocking
        await tester.tap(find.widgetWithText(FilledButton, 'Block'));
        await tester.pumpAndSettle();

        // 5. Block banner is displayed
        expect(
          find.textContaining('You have blocked this peer'),
          findsOneWidget,
        );
        expect(mockRepo.blocked, contains(testPeer.peerId));

        // 6. Input field is disabled
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);

        // 7. Open menu again and unblock
        await tester.tap(shieldButton);
        await tester.pumpAndSettle();

        expect(find.text('Unblock Peer'), findsOneWidget);
        await tester.tap(find.text('Unblock Peer'));
        await tester.pumpAndSettle();

        expect(mockRepo.blocked, isNot(contains(testPeer.peerId)));
        expect(find.textContaining('You have blocked this peer'), findsNothing);
      },
    );

    testWidgets(
      'ChatPage displays verified badge in title when peer is verified',
      (tester) async {
        final mockRepo = _MockSecurityRepo();
        mockRepo.trust = PeerTrust(
          peerNodeId: testPeer.peerId,
          peerPublicKey: 'test-pubkey',
          safetyFingerprint:
              '12345 67890 12345 67890 12345 67890 12345 67890 12345 67890 12345 67890',
          trustStatus: TrustStatus.verified,
          verifiedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        await tester.pumpWidget(
          createTestApp(
            ChatPage(
              peer: testPeer,
              messageService: messageService,
              securityRepository: mockRepo,
              isConnected: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.verified), findsOneWidget);
      },
    );

    testWidgets(
      'ChatPage displays security alert banner when peer key is mismatched',
      (tester) async {
        final mockRepo = _MockSecurityRepo();
        mockRepo.trust = PeerTrust(
          peerNodeId: testPeer.peerId,
          peerPublicKey: 'changed-key',
          safetyFingerprint: '00000',
          trustStatus: TrustStatus.mismatched,
          updatedAt: DateTime.now().toUtc(),
        );

        await tester.pumpWidget(
          createTestApp(
            ChatPage(
              peer: testPeer,
              messageService: messageService,
              securityRepository: mockRepo,
              isConnected: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Security Alert: Peer identity key has changed!'),
          findsOneWidget,
        );
      },
    );
  });
}
