import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/session/handshake_payload.dart';

void main() {
  group('HandshakePayload', () {
    test('HandshakeInitPayload encodes and decodes properly', () {
      final now = DateTime.utc(2026, 11, 17, 12, 0, 0);
      final payload = HandshakeInitPayload(
        senderNodeId: 'node-alice',
        senderIdentityPublicKey: 'deadbeef1234',
        ephemeralPublicKey: 'base64ephemeral',
        timestamp: now,
        signature: 'base64sig',
      );

      final encoded = payload.encode();
      final decoded = HandshakeInitPayload.decode(encoded);

      expect(decoded.senderNodeId, 'node-alice');
      expect(decoded.senderIdentityPublicKey, 'deadbeef1234');
      expect(decoded.ephemeralPublicKey, 'base64ephemeral');
      expect(decoded.timestamp, now);
      expect(decoded.signature, 'base64sig');
      expect(decoded.toSignableBytes(), equals(payload.toSignableBytes()));
    });

    test('HandshakeResponsePayload encodes and decodes properly', () {
      final now = DateTime.utc(2026, 11, 17, 12, 1, 0);
      final payload = HandshakeResponsePayload(
        senderNodeId: 'node-bob',
        recipientNodeId: 'node-alice',
        senderIdentityPublicKey: 'feedface5678',
        ephemeralPublicKey: 'base64bobephemeral',
        peerEphemeralPublicKey: 'base64aliceephemeral',
        timestamp: now,
        signature: 'base64bobsig',
      );

      final encoded = payload.encode();
      final decoded = HandshakeResponsePayload.decode(encoded);

      expect(decoded.senderNodeId, 'node-bob');
      expect(decoded.recipientNodeId, 'node-alice');
      expect(decoded.senderIdentityPublicKey, 'feedface5678');
      expect(decoded.ephemeralPublicKey, 'base64bobephemeral');
      expect(decoded.peerEphemeralPublicKey, 'base64aliceephemeral');
      expect(decoded.timestamp, now);
      expect(decoded.signature, 'base64bobsig');
      expect(decoded.toSignableBytes(), equals(payload.toSignableBytes()));
    });

    test('throws FormatException on malformed payloads', () {
      expect(
        () => HandshakeInitPayload.decode('{"incomplete": true}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => HandshakeResponsePayload.decode('{"incomplete": true}'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
