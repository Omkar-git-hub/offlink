import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/mesh/seen_message_cache.dart';

void main() {
  group('SeenMessageCache', () {
    test('marks unseen message and detects duplicates', () {
      final cache = SeenMessageCache();

      expect(cache.hasSeen('msg-1'), isFalse);
      expect(cache.markIfUnseen('msg-1'), isTrue);
      expect(cache.hasSeen('msg-1'), isTrue);

      // Duplicate detection
      expect(cache.markIfUnseen('msg-1'), isFalse);
      expect(cache.size, equals(1));
    });

    test('markSeen unconditionally records message ID', () {
      final cache = SeenMessageCache();

      cache.markSeen('msg-outbound-1');
      expect(cache.hasSeen('msg-outbound-1'), isTrue);
      expect(cache.markIfUnseen('msg-outbound-1'), isFalse);
    });

    test('prunes oldest entry when maximum capacity is exceeded', () {
      final cache = SeenMessageCache(maxCapacity: 3);

      cache.markSeen('msg-1');
      cache.markSeen('msg-2');
      cache.markSeen('msg-3');
      expect(cache.size, equals(3));

      // Adding 4th should prune oldest
      cache.markSeen('msg-4');
      expect(cache.size, equals(3));
      expect(cache.hasSeen('msg-1'), isFalse);
      expect(cache.hasSeen('msg-2'), isTrue);
      expect(cache.hasSeen('msg-3'), isTrue);
      expect(cache.hasSeen('msg-4'), isTrue);
    });

    test('expires entries older than entryTtl', () async {
      final cache = SeenMessageCache(
        entryTtl: const Duration(milliseconds: 50),
      );

      cache.markSeen('msg-expire');
      expect(cache.hasSeen('msg-expire'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(cache.hasSeen('msg-expire'), isFalse);
      expect(cache.markIfUnseen('msg-expire'), isTrue);
    });

    test('clear removes all entries', () {
      final cache = SeenMessageCache();
      cache.markSeen('msg-1');
      cache.markSeen('msg-2');
      expect(cache.size, equals(2));

      cache.clear();
      expect(cache.size, equals(0));
      expect(cache.hasSeen('msg-1'), isFalse);
    });
  });
}
