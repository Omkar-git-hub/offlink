import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/offlink_database.dart';

void main() {
  late OfflinkDatabase db;

  setUp(() {
    db = OfflinkDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('OfflinkDatabase Schema & Cascade Tests', () {
    test(
      'enforces foreign key cascading when conversation is deleted',
      () async {
        final now = DateTime.utc(2026, 10, 27, 10, 0);

        // Insert conversation
        await db
            .into(db.conversationsTable)
            .insert(
              ConversationsTableCompanion.insert(
                id: 'conv-alice',
                peerNodeId: 'node-alice-1234',
                peerDisplayName: 'Alice',
                updatedAt: now,
              ),
            );

        // Insert message tied to conversation
        await db
            .into(db.messagesTable)
            .insert(
              MessagesTableCompanion.insert(
                id: 'msg-1',
                conversationId: 'conv-alice',
                senderNodeId: 'node-bob-5678',
                recipientNodeId: 'node-alice-1234',
                content: 'Hello Alice!',
                timestamp: now,
                status: 'sent',
                isOutgoing: true,
              ),
            );

        // Verify message exists
        final messagesBefore = await (db.select(
          db.messagesTable,
        )..where((t) => t.conversationId.equals('conv-alice'))).get();
        expect(messagesBefore, hasLength(1));

        // Delete conversation
        await (db.delete(
          db.conversationsTable,
        )..where((t) => t.id.equals('conv-alice'))).go();

        // Messages should be cascade deleted
        final messagesAfter = await (db.select(
          db.messagesTable,
        )..where((t) => t.conversationId.equals('conv-alice'))).get();
        expect(messagesAfter, isEmpty);
      },
    );

    test('schema version is 1', () {
      expect(db.schemaVersion, 1);
    });
  });
}
