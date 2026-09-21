import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';

void main() {
  group('PacketTransport', () {
    test('defines the packet transport contract', () {
      expect(PacketTransport, isNotNull);
    });

    test('OfflinkPacket can be used by the transport contract', () {
      final packet = OfflinkPacket(
        messageId: 'message-001',
        senderNodeId: 'sender-001',
        recipientNodeId: 'receiver-001',
        messageType: OfflinkMessageType.text,
        timestamp: DateTime.utc(2026, 9, 21, 10),
        ttl: 8,
        payload: 'Hello Offlink',
      );

      expect(packet.messageId, 'message-001');
    });
  });
}
