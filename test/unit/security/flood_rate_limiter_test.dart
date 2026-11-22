import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/security/flood_rate_limiter.dart';

void main() {
  group('FloodRateLimiter', () {
    late FloodRateLimiter limiter;

    setUp(() {
      limiter = FloodRateLimiter(
        maxPacketsPerWindow: 5,
        windowDuration: const Duration(seconds: 2),
        quarantineThreshold: 3,
        quarantineDuration: const Duration(seconds: 10),
      );
    });

    test('allows packets within window threshold', () {
      final now = DateTime.utc(2026, 11, 23, 12, 0, 0);

      for (var i = 0; i < 5; i++) {
        final allowed = limiter.allowPacket('node-peer-1', now: now);
        expect(allowed, isTrue, reason: 'Packet $i should be allowed');
      }

      // 6th packet in the same window exceeds threshold
      expect(limiter.allowPacket('node-peer-1', now: now), isFalse);
    });

    test('different peers have independent rate limits', () {
      final now = DateTime.utc(2026, 11, 23, 12, 0, 0);

      for (var i = 0; i < 5; i++) {
        expect(limiter.allowPacket('peer-a', now: now), isTrue);
      }
      expect(limiter.allowPacket('peer-a', now: now), isFalse);

      // peer-b should still be allowed
      expect(limiter.allowPacket('peer-b', now: now), isTrue);
    });

    test('drops packets with empty sender nodeId', () {
      expect(limiter.allowPacket(''), isFalse);
      expect(limiter.allowPacket('   '), isFalse);
    });

    test('resets packet count after window expires', () {
      final t0 = DateTime.utc(2026, 11, 23, 12, 0, 0);
      for (var i = 0; i < 5; i++) {
        limiter.allowPacket('peer-1', now: t0);
      }
      expect(limiter.allowPacket('peer-1', now: t0), isFalse);

      // Advance time past windowDuration (2s)
      final t1 = t0.add(const Duration(seconds: 3));
      expect(limiter.allowPacket('peer-1', now: t1), isTrue);
    });

    test(
      'triggers quarantine after threshold violations and drops packets during quarantine',
      () {
        final t0 = DateTime.utc(2026, 11, 23, 12, 0, 0);

        // Fill window
        for (var i = 0; i < 5; i++) {
          limiter.allowPacket('spammer', now: t0);
        }

        // 3 consecutive violations (quarantineThreshold = 3)
        expect(limiter.allowPacket('spammer', now: t0), isFalse); // violation 1
        expect(limiter.allowPacket('spammer', now: t0), isFalse); // violation 2
        expect(
          limiter.allowPacket('spammer', now: t0),
          isFalse,
        ); // violation 3 -> quarantined!

        expect(limiter.isQuarantined('spammer', now: t0), isTrue);

        // During quarantine, packets are blocked even if window has passed
        final tDuring = t0.add(const Duration(seconds: 5));
        expect(limiter.allowPacket('spammer', now: tDuring), isFalse);
        expect(limiter.isQuarantined('spammer', now: tDuring), isTrue);

        // After quarantineDuration (10s), quarantine lifts
        final tAfter = t0.add(const Duration(seconds: 11));
        expect(limiter.isQuarantined('spammer', now: tAfter), isFalse);
        expect(limiter.allowPacket('spammer', now: tAfter), isTrue);
      },
    );

    test('reset and resetAll clear tracking state', () {
      final now = DateTime.utc(2026, 11, 23, 12, 0, 0);
      for (var i = 0; i < 5; i++) {
        limiter.allowPacket('peer-1', now: now);
        limiter.allowPacket('peer-2', now: now);
      }
      expect(limiter.allowPacket('peer-1', now: now), isFalse);
      expect(limiter.allowPacket('peer-2', now: now), isFalse);

      limiter.reset('peer-1');
      expect(limiter.allowPacket('peer-1', now: now), isTrue);
      expect(limiter.allowPacket('peer-2', now: now), isFalse);

      limiter.resetAll();
      expect(limiter.allowPacket('peer-2', now: now), isTrue);
    });

    test('pruneStale removes old inactive peer records', () {
      final t0 = DateTime.utc(2026, 11, 23, 12, 0, 0);
      limiter.allowPacket('peer-old', now: t0);

      final t1 = t0.add(const Duration(minutes: 5));
      limiter.pruneStale(now: t1, maxAge: const Duration(minutes: 2));

      // peer-old state was pruned, so new packet creates fresh state
      expect(limiter.allowPacket('peer-old', now: t1), isTrue);
    });
  });
}
