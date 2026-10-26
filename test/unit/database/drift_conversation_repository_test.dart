import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/messaging/conversation.dart';

void main() {
  late OfflinkDatabase db;
  late DriftConversationRepository repository;

  setUp(() {
    db = OfflinkDatabase.forTesting(NativeDatabase.memory());
    repository = DriftConversationRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftConversationRepository', () {
    test('upserts and retrieves conversation by ID and by Peer', () async {
      final now = DateTime.utc(2026, 10, 27, 10, 0);
      final conversation = Conversation(
        id: 'conv-bob',
        peerNodeId: 'node-bob-5678',
        peerDisplayName: 'Bob',
        lastMessage: 'Hey there',
        unreadCount: 2,
        updatedAt: now,
      );

      await repository.upsertConversation(conversation);

      final byId = await repository.getConversationById('conv-bob');
      expect(byId, isNotNull);
      expect(byId!.id, 'conv-bob');
      expect(byId.peerNodeId, 'node-bob-5678');
      expect(byId.peerDisplayName, 'Bob');
      expect(byId.lastMessage, 'Hey there');
      expect(byId.unreadCount, 2);
      expect(byId.updatedAt, now);

      final byPeer = await repository.getConversationByPeer('node-bob-5678');
      expect(byPeer, isNotNull);
      expect(byPeer!.id, 'conv-bob');
    });

    test('updates existing conversation on conflict', () async {
      final t1 = DateTime.utc(2026, 10, 27, 10, 0);
      final t2 = DateTime.utc(2026, 10, 27, 10, 5);

      await repository.upsertConversation(
        Conversation(
          id: 'conv-1',
          peerNodeId: 'node-1',
          peerDisplayName: 'Peer One',
          lastMessage: 'First message',
          unreadCount: 1,
          updatedAt: t1,
        ),
      );

      await repository.upsertConversation(
        Conversation(
          id: 'conv-1',
          peerNodeId: 'node-1',
          peerDisplayName: 'Peer One',
          lastMessage: 'Updated message',
          unreadCount: 2,
          updatedAt: t2,
        ),
      );

      final result = await repository.getConversationById('conv-1');
      expect(result!.lastMessage, 'Updated message');
      expect(result.unreadCount, 2);
      expect(result.updatedAt, t2);
    });

    test('getAllConversations orders by updatedAt descending', () async {
      final t1 = DateTime.utc(2026, 10, 27, 9, 0);
      final t2 = DateTime.utc(2026, 10, 27, 10, 0);
      final t3 = DateTime.utc(2026, 10, 27, 8, 0);

      await repository.upsertConversation(
        Conversation(
          id: 'c1',
          peerNodeId: 'n1',
          peerDisplayName: 'P1',
          updatedAt: t1,
        ),
      );
      await repository.upsertConversation(
        Conversation(
          id: 'c2',
          peerNodeId: 'n2',
          peerDisplayName: 'P2',
          updatedAt: t2,
        ),
      );
      await repository.upsertConversation(
        Conversation(
          id: 'c3',
          peerNodeId: 'n3',
          peerDisplayName: 'P3',
          updatedAt: t3,
        ),
      );

      final list = await repository.getAllConversations();
      expect(list.map((c) => c.id).toList(), ['c2', 'c1', 'c3']);
    });

    test('markConversationAsRead resets unread count to 0', () async {
      await repository.upsertConversation(
        Conversation(
          id: 'conv-unread',
          peerNodeId: 'node-unread',
          peerDisplayName: 'Unread Peer',
          unreadCount: 5,
          updatedAt: DateTime.utc(2026, 10, 27, 10, 0),
        ),
      );

      await repository.markConversationAsRead('conv-unread');

      final updated = await repository.getConversationById('conv-unread');
      expect(updated!.unreadCount, 0);
    });

    test('deleteConversation removes the conversation record', () async {
      await repository.upsertConversation(
        Conversation(
          id: 'conv-delete',
          peerNodeId: 'node-delete',
          peerDisplayName: 'To Delete',
          updatedAt: DateTime.utc(2026, 10, 27, 10, 0),
        ),
      );

      await repository.deleteConversation('conv-delete');

      final result = await repository.getConversationById('conv-delete');
      expect(result, isNull);
    });

    test('watchAllConversations streams conversation updates', () async {
      final stream = repository.watchAllConversations();

      final firstEmission = stream.first;
      await repository.upsertConversation(
        Conversation(
          id: 'c-watch',
          peerNodeId: 'n-watch',
          peerDisplayName: 'Watcher',
          updatedAt: DateTime.utc(2026, 10, 27, 10, 0),
        ),
      );

      final conversations = await firstEmission;
      expect(conversations, hasLength(1));
      expect(conversations.first.id, 'c-watch');
    });
  });
}
