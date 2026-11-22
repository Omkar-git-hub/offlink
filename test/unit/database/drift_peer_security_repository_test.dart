import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/drift_peer_security_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/security/trust_status.dart';

void main() {
  late OfflinkDatabase database;
  late DriftPeerSecurityRepository repository;

  setUp(() {
    database = OfflinkDatabase.forTesting(NativeDatabase.memory());
    repository = DriftPeerSecurityRepository(database);
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  group('DriftPeerSecurityRepository - Blocked Peers', () {
    test('blockPeer and isPeerBlocked (async and sync)', () async {
      expect(await repository.isPeerBlocked('node-bad'), isFalse);
      expect(repository.isPeerBlockedSync('node-bad'), isFalse);

      await repository.blockPeer('node-bad', reason: 'harassment');

      expect(await repository.isPeerBlocked('node-bad'), isTrue);
      expect(repository.isPeerBlockedSync('node-bad'), isTrue);

      final blocked = await repository.getBlockedPeers();
      expect(blocked, hasLength(1));
      expect(blocked.first.nodeId, equals('node-bad'));
      expect(blocked.first.reason, equals('harassment'));

      await repository.unblockPeer('node-bad');
      expect(await repository.isPeerBlocked('node-bad'), isFalse);
      expect(repository.isPeerBlockedSync('node-bad'), isFalse);

      final blockedAfter = await repository.getBlockedPeers();
      expect(blockedAfter, isEmpty);
    });

    test('watchBlockedPeers emits updates on block and unblock', () async {
      final stream = repository.watchBlockedPeers();

      expect(stream, emitsInOrder([isEmpty, hasLength(1), isEmpty]));

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repository.blockPeer('node-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repository.unblockPeer('node-1');
    });
  });

  group('DriftPeerSecurityRepository - Peer Trust', () {
    test('saveOrUpdatePeerTrust and getPeerTrust', () async {
      final now = DateTime.utc(2026, 11, 23, 10, 0);
      final trust = PeerTrust(
        peerNodeId: 'node-alice',
        peerPublicKey: 'alice-pubkey-hex',
        safetyFingerprint:
            '12345 67890 12345 67890 12345 67890 12345 67890 12345 67890 12345 67890',
        trustStatus: TrustStatus.unverified,
        updatedAt: now,
      );

      await repository.saveOrUpdatePeerTrust(trust);

      final fetched = await repository.getPeerTrust('node-alice');
      expect(fetched, isNotNull);
      expect(fetched!.peerNodeId, equals('node-alice'));
      expect(fetched.peerPublicKey, equals('alice-pubkey-hex'));
      expect(fetched.safetyFingerprint, equals(trust.safetyFingerprint));
      expect(fetched.trustStatus, equals(TrustStatus.unverified));
      expect(fetched.isVerified, isFalse);
      expect(fetched.isMismatched, isFalse);

      // Update trust status to verified
      await repository.setPeerVerificationStatus(
        'node-alice',
        TrustStatus.verified,
      );

      final updated = await repository.getPeerTrust('node-alice');
      expect(updated, isNotNull);
      expect(updated!.trustStatus, equals(TrustStatus.verified));
      expect(updated.isVerified, isTrue);
      expect(updated.verifiedAt, isNotNull);

      // Update trust status to mismatched
      await repository.setPeerVerificationStatus(
        'node-alice',
        TrustStatus.mismatched,
      );

      final mismatched = await repository.getPeerTrust('node-alice');
      expect(mismatched, isNotNull);
      expect(mismatched!.trustStatus, equals(TrustStatus.mismatched));
      expect(mismatched.isMismatched, isTrue);
      expect(mismatched.verifiedAt, isNull);
    });

    test('getPeerTrust returns null for unknown peer', () async {
      final trust = await repository.getPeerTrust('unknown-peer');
      expect(trust, isNull);
    });
  });
}
