import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/security/peer_security_repository.dart';
import 'package:offlink/domain/security/trust_status.dart';
import 'package:offlink/features/chat/safety_fingerprint_dialog.dart';

class _FakeSecurityRepository implements PeerSecurityRepository {
  PeerTrust? trustRecord;
  final List<String> blocked = [];

  @override
  Future<void> blockPeer(String nodeId, {String reason = 'manual'}) async {
    blocked.add(nodeId);
  }

  @override
  Future<void> unblockPeer(String nodeId) async {
    blocked.remove(nodeId);
  }

  @override
  Future<bool> isPeerBlocked(String nodeId) async => blocked.contains(nodeId);

  @override
  bool isPeerBlockedSync(String nodeId) => blocked.contains(nodeId);

  @override
  Future<List<BlockedPeer>> getBlockedPeers() async => [];

  @override
  Stream<List<BlockedPeer>> watchBlockedPeers() => const Stream.empty();

  @override
  Future<PeerTrust?> getPeerTrust(String peerNodeId) async => trustRecord;

  @override
  Future<void> saveOrUpdatePeerTrust(PeerTrust trust) async {
    trustRecord = trust;
  }

  @override
  Future<void> setPeerVerificationStatus(
    String peerNodeId,
    TrustStatus status,
  ) async {
    trustRecord =
        trustRecord?.copyWith(trustStatus: status) ??
        PeerTrust(
          peerNodeId: peerNodeId,
          peerPublicKey: 'test-key',
          safetyFingerprint:
              '12345 67890 12345 67890 12345 67890 12345 67890 12345 67890 12345 67890',
          trustStatus: status,
          updatedAt: DateTime.now().toUtc(),
        );
  }
}

void main() {
  const localKey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const peerKey =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  Widget buildTestWidget({
    required PeerSecurityRepository securityRepo,
    PeerTrust? initialTrust,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SafetyFingerprintDialog(
          peerNodeId: 'peer-alice',
          peerDisplayName: 'Alice',
          localPublicKeyHex: localKey,
          peerPublicKeyHex: peerKey,
          securityRepository: securityRepo,
          initialTrust: initialTrust,
        ),
      ),
    );
  }

  group('SafetyFingerprintDialog Widget Tests', () {
    testWidgets('renders title, peer display name, and safety numbers', (
      tester,
    ) async {
      final repo = _FakeSecurityRepository();

      await tester.pumpWidget(buildTestWidget(securityRepo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Safety Fingerprint'), findsOneWidget);
      expect(
        find.textContaining('Compare this number with Alice'),
        findsOneWidget,
      );
      expect(find.text('Unverified'), findsOneWidget);
      expect(find.text('Mark as Verified'), findsOneWidget);
    });

    testWidgets(
      'toggling verification updates status to verified and button to clear verification',
      (tester) async {
        final repo = _FakeSecurityRepository();

        await tester.pumpWidget(buildTestWidget(securityRepo: repo));
        await tester.pumpAndSettle();

        expect(find.text('Unverified'), findsOneWidget);
        expect(find.text('Mark as Verified'), findsOneWidget);

        await tester.tap(find.text('Mark as Verified'));
        await tester.pumpAndSettle();

        expect(find.text('Verified'), findsOneWidget);
        expect(find.text('Clear Verification'), findsOneWidget);
        expect(repo.trustRecord?.trustStatus, equals(TrustStatus.verified));
      },
    );

    testWidgets('renders warning alert banner when trustStatus is mismatched', (
      tester,
    ) async {
      final repo = _FakeSecurityRepository();
      final mismatchedTrust = PeerTrust(
        peerNodeId: 'peer-alice',
        peerPublicKey: peerKey,
        safetyFingerprint: '00000',
        trustStatus: TrustStatus.mismatched,
        updatedAt: DateTime.now().toUtc(),
      );
      repo.trustRecord = mismatchedTrust;

      await tester.pumpWidget(
        buildTestWidget(securityRepo: repo, initialTrust: mismatchedTrust),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'WARNING: This peer\'s identity public key has changed!',
        ),
        findsOneWidget,
      );
      expect(find.text('Key Mismatched'), findsOneWidget);
    });
  });
}
