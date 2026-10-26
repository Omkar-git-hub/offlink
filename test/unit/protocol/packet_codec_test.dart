import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_codec.dart';

void main() {
  const codec = PacketCodec();

  group('PacketCodec', () {
    test('encodes an Offlink packet', () {
      final packet = OfflinkPacket(
        messageId: 'message-001',
        senderNodeId: 'sender-001',
        recipientNodeId: 'receiver-001',
        messageType: OfflinkMessageType.text,
        timestamp: DateTime.utc(2026, 9, 21, 10),
        ttl: 8,
        payload: 'Hello Offlink',
      );

      final encoded = codec.encode(packet);

      expect(encoded, isNotEmpty);
      expect(encoded, contains('message-001'));
      expect(encoded, contains('Hello Offlink'));
    });

    test('decodes an encoded Offlink packet', () {
      final packet = OfflinkPacket(
        messageId: 'message-002',
        senderNodeId: 'sender-002',
        recipientNodeId: 'receiver-002',
        messageType: OfflinkMessageType.text,
        timestamp: DateTime.utc(2026, 9, 21, 11),
        ttl: 6,
        payload: 'Protocol test',
      );

      final encoded = codec.encode(packet);
      final decoded = codec.decode(encoded);

      expect(decoded.messageId, packet.messageId);
      expect(decoded.senderNodeId, packet.senderNodeId);
      expect(decoded.recipientNodeId, packet.recipientNodeId);
      expect(decoded.messageType, packet.messageType);
      expect(decoded.timestamp, packet.timestamp);
      expect(decoded.ttl, packet.ttl);
      expect(decoded.payload, packet.payload);
    });

    test('throws when decoding invalid packet data', () {
      expect(
        () => codec.decode('invalid-json'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
