import 'dart:convert';

import 'offlink_message_type.dart';
import 'protocol_version.dart';

class OfflinkPacket {
  const OfflinkPacket({
    required this.messageId,
    required this.senderNodeId,
    required this.recipientNodeId,
    required this.messageType,
    required this.timestamp,
    required this.ttl,
    required this.payload,
    this.version = ProtocolVersion.current,
  });

  final int version;
  final String messageId;
  final String senderNodeId;
  final String recipientNodeId;
  final OfflinkMessageType messageType;
  final DateTime timestamp;
  final int ttl;
  final String payload;

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'messageId': messageId,
      'senderNodeId': senderNodeId,
      'recipientNodeId': recipientNodeId,
      'messageType': messageType.value,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'ttl': ttl,
      'payload': payload,
    };
  }

  String encode() {
    return jsonEncode(toMap());
  }

  factory OfflinkPacket.fromMap(Map<String, dynamic> map) {
    return OfflinkPacket(
      version: map['version'] as int,
      messageId: map['messageId'] as String,
      senderNodeId: map['senderNodeId'] as String,
      recipientNodeId: map['recipientNodeId'] as String,
      messageType: OfflinkMessageTypeCodec.fromValue(
        map['messageType'] as String,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String).toUtc(),
      ttl: map['ttl'] as int,
      payload: map['payload'] as String,
    );
  }

  factory OfflinkPacket.decode(String encoded) {
    final decoded = jsonDecode(encoded);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Offlink packet must be a JSON object.');
    }

    return OfflinkPacket.fromMap(decoded);
  }
}
