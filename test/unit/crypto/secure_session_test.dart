import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/session/secure_session.dart';

void main() {
  group('SecureSession', () {
    test('maintains outbound and inbound sequence numbers', () async {
      final session = SecureSession(
        sessionId: 'sess-1',
        peerNodeId: 'peer-node',
        peerIdentityPublicKey: 'hex-key',
        sessionKey: await AesGcm.with256bits().newSecretKey(),
        sessionFingerprint: 'fingerprint-123',
        establishedAt: DateTime.utc(2026, 11, 17),
      );

      expect(session.outboundSequenceNumber, 0);
      expect(session.lastInboundSequenceNumber, 0);

      // Outbound increment
      expect(session.nextOutboundSequenceNumber(), 1);
      expect(session.nextOutboundSequenceNumber(), 2);
      expect(session.outboundSequenceNumber, 2);

      // Inbound validation and update
      expect(session.isValidInboundSequence(1), isTrue);
      session.updateInboundSequence(1);
      expect(session.lastInboundSequenceNumber, 1);

      // Sequence <= last received is invalid (replay)
      expect(session.isValidInboundSequence(1), isFalse);
      expect(session.isValidInboundSequence(0), isFalse);
      expect(
        () => session.updateInboundSequence(1),
        throwsA(isA<StateError>()),
      );

      // Greater sequence is valid
      expect(session.isValidInboundSequence(2), isTrue);
      session.updateInboundSequence(2);
      expect(session.lastInboundSequenceNumber, 2);
    });
  });
}
