import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';

void main() {
  group('OfflinkPacket', () {
    test('encodes and decodes a text packet', () {
      final packet = OfflinkPacket(
        messageId: 'message-001',
        senderNodeId: 'sender-001',
        recipientNodeId: 'receiver-001',
        messageType: OfflinkMessageType.text,
        timestamp: DateTime.utc(2026, 9, 21, 10),
        ttl: 8,
        payload: 'Hello Offlink',
      );

      final encoded = packet.encode();
      final decoded = OfflinkPacket.decode(encoded);

      expect(decoded.version, packet.version);
      expect(decoded.messageId, packet.messageId);
      expect(decoded.senderNodeId, packet.senderNodeId);
      expect(decoded.recipientNodeId, packet.recipientNodeId);
      expect(decoded.messageType, packet.messageType);
      expect(decoded.timestamp, packet.timestamp);
      expect(decoded.ttl, packet.ttl);
      expect(decoded.payload, packet.payload);
    });

    test('rejects a non-object JSON packet', () {
      expect(() => OfflinkPacket.decode('[]'), throwsA(isA<FormatException>()));
    });
  });
}
