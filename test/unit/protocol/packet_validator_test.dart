import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_validator.dart';

void main() {
  final validator = PacketValidator();

  OfflinkPacket createPacket({
    int ttl = 8,
    String messageId = 'message-001',
    String senderNodeId = 'sender-001',
    String recipientNodeId = 'receiver-001',
    String payload = 'Hello Offlink',
  }) {
    return OfflinkPacket(
      messageId: messageId,
      senderNodeId: senderNodeId,
      recipientNodeId: recipientNodeId,
      messageType: OfflinkMessageType.text,
      timestamp: DateTime.utc(2026, 9, 21, 10),
      ttl: ttl,
      payload: payload,
    );
  }

  group('PacketValidator', () {
    test('accepts a valid packet', () {
      expect(validator.isValid(createPacket()), isTrue);
    });

    test('rejects an empty message id', () {
      expect(validator.isValid(createPacket(messageId: '')), isFalse);
    });

    test('rejects an empty sender node id', () {
      expect(validator.isValid(createPacket(senderNodeId: '')), isFalse);
    });

    test('rejects an empty recipient node id', () {
      expect(validator.isValid(createPacket(recipientNodeId: '')), isFalse);
    });

    test('rejects a negative ttl', () {
      expect(validator.isValid(createPacket(ttl: -1)), isFalse);
    });

    test('rejects ttl above the maximum', () {
      expect(validator.isValid(createPacket(ttl: 17)), isFalse);
    });

    test('rejects an oversized payload', () {
      expect(validator.isValid(createPacket(payload: 'a' * 4097)), isFalse);
    });
  });
}
