import 'dart:convert';

class HandshakeInitPayload {
  const HandshakeInitPayload({
    required this.senderNodeId,
    required this.senderIdentityPublicKey,
    required this.ephemeralPublicKey,
    required this.timestamp,
    required this.signature,
  });

  final String senderNodeId;
  final String senderIdentityPublicKey;
  final String ephemeralPublicKey;
  final DateTime timestamp;
  final String signature;

  List<int> toSignableBytes() {
    return utf8.encode(
      'init:$senderNodeId:$senderIdentityPublicKey:$ephemeralPublicKey:${timestamp.toUtc().toIso8601String()}',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderNodeId': senderNodeId,
      'senderIdentityPublicKey': senderIdentityPublicKey,
      'ephemeralPublicKey': ephemeralPublicKey,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'signature': signature,
    };
  }

  String encode() {
    return jsonEncode(toMap());
  }

  factory HandshakeInitPayload.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('senderNodeId') ||
        !map.containsKey('senderIdentityPublicKey') ||
        !map.containsKey('ephemeralPublicKey') ||
        !map.containsKey('timestamp') ||
        !map.containsKey('signature')) {
      throw const FormatException(
        'Missing required fields for HandshakeInitPayload.',
      );
    }

    return HandshakeInitPayload(
      senderNodeId: map['senderNodeId'] as String,
      senderIdentityPublicKey: map['senderIdentityPublicKey'] as String,
      ephemeralPublicKey: map['ephemeralPublicKey'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String).toUtc(),
      signature: map['signature'] as String,
    );
  }

  factory HandshakeInitPayload.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'HandshakeInitPayload must be a JSON object.',
      );
    }
    return HandshakeInitPayload.fromMap(decoded);
  }
}

class HandshakeResponsePayload {
  const HandshakeResponsePayload({
    required this.senderNodeId,
    required this.recipientNodeId,
    required this.senderIdentityPublicKey,
    required this.ephemeralPublicKey,
    required this.peerEphemeralPublicKey,
    required this.timestamp,
    required this.signature,
  });

  final String senderNodeId;
  final String recipientNodeId;
  final String senderIdentityPublicKey;
  final String ephemeralPublicKey;
  final String peerEphemeralPublicKey;
  final DateTime timestamp;
  final String signature;

  List<int> toSignableBytes() {
    return utf8.encode(
      'resp:$senderNodeId:$recipientNodeId:$senderIdentityPublicKey:$ephemeralPublicKey:$peerEphemeralPublicKey:${timestamp.toUtc().toIso8601String()}',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderNodeId': senderNodeId,
      'recipientNodeId': recipientNodeId,
      'senderIdentityPublicKey': senderIdentityPublicKey,
      'ephemeralPublicKey': ephemeralPublicKey,
      'peerEphemeralPublicKey': peerEphemeralPublicKey,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'signature': signature,
    };
  }

  String encode() {
    return jsonEncode(toMap());
  }

  factory HandshakeResponsePayload.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('senderNodeId') ||
        !map.containsKey('recipientNodeId') ||
        !map.containsKey('senderIdentityPublicKey') ||
        !map.containsKey('ephemeralPublicKey') ||
        !map.containsKey('peerEphemeralPublicKey') ||
        !map.containsKey('timestamp') ||
        !map.containsKey('signature')) {
      throw const FormatException(
        'Missing required fields for HandshakeResponsePayload.',
      );
    }

    return HandshakeResponsePayload(
      senderNodeId: map['senderNodeId'] as String,
      recipientNodeId: map['recipientNodeId'] as String,
      senderIdentityPublicKey: map['senderIdentityPublicKey'] as String,
      ephemeralPublicKey: map['ephemeralPublicKey'] as String,
      peerEphemeralPublicKey: map['peerEphemeralPublicKey'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String).toUtc(),
      signature: map['signature'] as String,
    );
  }

  factory HandshakeResponsePayload.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'HandshakeResponsePayload must be a JSON object.',
      );
    }
    return HandshakeResponsePayload.fromMap(decoded);
  }
}
