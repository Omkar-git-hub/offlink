// ignore_for_file: prefer_initializing_formals

import 'package:cryptography/cryptography.dart';

class SecureSession {
  SecureSession({
    required this.sessionId,
    required this.peerNodeId,
    required this.peerIdentityPublicKey,
    required this.sessionKey,
    required this.sessionFingerprint,
    required this.establishedAt,
    int outboundSequenceNumber = 0,
    int lastInboundSequenceNumber = 0,
  }) : _outboundSequenceNumber = outboundSequenceNumber,
       _lastInboundSequenceNumber = lastInboundSequenceNumber;

  final String sessionId;
  final String peerNodeId;
  final String peerIdentityPublicKey;
  final SecretKey sessionKey;
  final String sessionFingerprint;
  final DateTime establishedAt;

  int _outboundSequenceNumber;
  int _lastInboundSequenceNumber;

  int get outboundSequenceNumber => _outboundSequenceNumber;
  int get lastInboundSequenceNumber => _lastInboundSequenceNumber;

  int nextOutboundSequenceNumber() {
    _outboundSequenceNumber += 1;
    return _outboundSequenceNumber;
  }

  bool isValidInboundSequence(int sequenceNumber) {
    return sequenceNumber > _lastInboundSequenceNumber;
  }

  void updateInboundSequence(int sequenceNumber) {
    if (sequenceNumber <= _lastInboundSequenceNumber) {
      throw StateError(
        'Inbound sequence number must be strictly greater than last received: '
        '$sequenceNumber <= $_lastInboundSequenceNumber',
      );
    }
    _lastInboundSequenceNumber = sequenceNumber;
  }
}
