import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/message_service.dart';
import 'package:offlink/features/chat/chat_page.dart';

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
  });
}
