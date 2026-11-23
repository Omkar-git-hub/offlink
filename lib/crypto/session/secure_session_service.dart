// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../identity/identity_key_service.dart';
import 'encrypted_payload.dart';
import 'handshake_payload.dart';
import 'secure_session.dart';

class SecureSessionException implements Exception {
  SecureSessionException(this.message);
  final String message;
  @override
  String toString() => 'SecureSessionException: $message';
}

class SessionNotFoundException extends SecureSessionException {
  SessionNotFoundException(super.message);
}

class HandshakeValidationException extends SecureSessionException {
  HandshakeValidationException(super.message);
}

class ReplayAttackException extends SecureSessionException {
  ReplayAttackException(super.message);
}

class DecryptionAuthenticationException extends SecureSessionException {
  DecryptionAuthenticationException(super.message);
}

class _PendingHandshake {
  _PendingHandshake({required this.ephemeralKeyPair, required this.timestamp});

  final SimpleKeyPair ephemeralKeyPair;
  final DateTime timestamp;
}

class SecureSessionService {
  SecureSessionService({
    required IdentityKeyService identityKeyService,
    required String Function() getLocalNodeId,
    Ed25519? ed25519,
    X25519? x25519,
    Hkdf? hkdf,
    AesGcm? aesGcm,
  }) : _identityKeyService = identityKeyService,
       _getLocalNodeId = getLocalNodeId,
       _ed25519 = ed25519 ?? Ed25519(),
       _x25519 = x25519 ?? X25519(),
       _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32),
       _aesGcm = aesGcm ?? AesGcm.with256bits();

  final IdentityKeyService _identityKeyService;
  final String Function() _getLocalNodeId;
  final Ed25519 _ed25519;
  final X25519 _x25519;
  final Hkdf _hkdf;
  final AesGcm _aesGcm;

  static final List<int> _sessionSalt = utf8.encode('offlink-session-salt-v1');
  static final List<int> _sessionInfo = utf8.encode('offlink-aes-256-gcm-key');

  final Map<String, SecureSession> _sessions = {};
  final Map<String, _PendingHandshake> _pendingHandshakes = {};

  bool hasSession(String peerNodeId) => _sessions.containsKey(peerNodeId);

  SecureSession? getSession(String peerNodeId) => _sessions[peerNodeId];

  void terminateSession(String peerNodeId) {
    _sessions.remove(peerNodeId);
    _pendingHandshakes.remove(peerNodeId);
  }

  void terminateAllSessions() {
    _sessions.clear();
    _pendingHandshakes.clear();
  }

  Future<HandshakeInitPayload> createHandshakeInit(
    String recipientNodeId, {
    String? senderUsername,
  }) async {
    final localIdentityKeyPair = await _identityKeyService.loadPrivateKey();
    if (localIdentityKeyPair == null) {
      throw StateError('Local identity keypair is not available.');
    }

    final localIdentityPublicKey = await localIdentityKeyPair
        .extractPublicKey();
    final localIdentityHex = _bytesToHex(localIdentityPublicKey.bytes);

    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    final ephemeralBase64 = base64Encode(ephemeralPublicKey.bytes);

    final now = DateTime.now().toUtc();
    final localNodeId = _getLocalNodeId();

    _pendingHandshakes[recipientNodeId] = _PendingHandshake(
      ephemeralKeyPair: ephemeralKeyPair,
      timestamp: now,
    );

    final unsignedPayload = HandshakeInitPayload(
      senderNodeId: localNodeId,
      senderIdentityPublicKey: localIdentityHex,
      ephemeralPublicKey: ephemeralBase64,
      timestamp: now,
      signature: '',
      senderUsername: senderUsername,
    );

    final signature = await _ed25519.sign(
      unsignedPayload.toSignableBytes(),
      keyPair: localIdentityKeyPair,
    );

    return HandshakeInitPayload(
      senderNodeId: localNodeId,
      senderIdentityPublicKey: localIdentityHex,
      ephemeralPublicKey: ephemeralBase64,
      timestamp: now,
      signature: base64Encode(signature.bytes),
      senderUsername: senderUsername,
    );
  }

  Future<HandshakeResponsePayload> handleHandshakeInit(
    HandshakeInitPayload initPayload, {
    String? senderUsername,
  }) async {
    final localIdentityKeyPair = await _identityKeyService.loadPrivateKey();
    if (localIdentityKeyPair == null) {
      throw StateError('Local identity keypair is not available.');
    }

    final peerIdentityBytes = _hexToBytes(initPayload.senderIdentityPublicKey);
    final peerIdentityPublicKey = SimplePublicKey(
      peerIdentityBytes,
      type: KeyPairType.ed25519,
    );

    final sigBytes = _decodeBase64Safe(initPayload.signature);
    if (sigBytes.length != 64) {
      throw HandshakeValidationException('Signature must be exactly 64 bytes.');
    }

    bool isSignatureValid;
    try {
      isSignatureValid = await _ed25519.verify(
        initPayload.toSignableBytes(),
        signature: Signature(sigBytes, publicKey: peerIdentityPublicKey),
      );
    } catch (e) {
      throw HandshakeValidationException('Signature verification failed: $e');
    }

    if (!isSignatureValid) {
      throw HandshakeValidationException(
        'Invalid Ed25519 signature on HandshakeInit from ${initPayload.senderNodeId}.',
      );
    }

    final ephemeralKeyPair = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    final ephemeralBase64 = base64Encode(ephemeralPublicKey.bytes);

    final peerEphemeralPublicKey = SimplePublicKey(
      base64Decode(initPayload.ephemeralPublicKey),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: peerEphemeralPublicKey,
    );

    final sessionKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: _sessionSalt,
      info: _sessionInfo,
    );

    final sessionKeyBytes = await sessionKey.extractBytes();
    final hash = await Sha256().hash(sessionKeyBytes);
    final sessionFingerprint = _bytesToHex(hash.bytes).substring(0, 16);

    final session = SecureSession(
      sessionId: 'sess-${DateTime.now().microsecondsSinceEpoch}',
      peerNodeId: initPayload.senderNodeId,
      peerIdentityPublicKey: initPayload.senderIdentityPublicKey,
      sessionKey: sessionKey,
      sessionFingerprint: sessionFingerprint,
      establishedAt: DateTime.now().toUtc(),
    );
    _sessions[initPayload.senderNodeId] = session;

    final localIdentityPublicKey = await localIdentityKeyPair
        .extractPublicKey();
    final localIdentityHex = _bytesToHex(localIdentityPublicKey.bytes);
    final localNodeId = _getLocalNodeId();
    final now = DateTime.now().toUtc();

    final unsignedResponse = HandshakeResponsePayload(
      senderNodeId: localNodeId,
      recipientNodeId: initPayload.senderNodeId,
      senderIdentityPublicKey: localIdentityHex,
      ephemeralPublicKey: ephemeralBase64,
      peerEphemeralPublicKey: initPayload.ephemeralPublicKey,
      timestamp: now,
      signature: '',
      senderUsername: senderUsername,
    );

    final signature = await _ed25519.sign(
      unsignedResponse.toSignableBytes(),
      keyPair: localIdentityKeyPair,
    );

    return HandshakeResponsePayload(
      senderNodeId: localNodeId,
      recipientNodeId: initPayload.senderNodeId,
      senderIdentityPublicKey: localIdentityHex,
      ephemeralPublicKey: ephemeralBase64,
      peerEphemeralPublicKey: initPayload.ephemeralPublicKey,
      timestamp: now,
      signature: base64Encode(signature.bytes),
      senderUsername: senderUsername,
    );
  }

  Future<SecureSession> handleHandshakeResponse(
    HandshakeResponsePayload responsePayload,
  ) async {
    final pending = _pendingHandshakes[responsePayload.senderNodeId];
    if (pending == null) {
      throw HandshakeValidationException(
        'No pending handshake found for peer ${responsePayload.senderNodeId}.',
      );
    }

    final peerIdentityBytes = _hexToBytes(
      responsePayload.senderIdentityPublicKey,
    );
    final peerIdentityPublicKey = SimplePublicKey(
      peerIdentityBytes,
      type: KeyPairType.ed25519,
    );

    final sigBytes = _decodeBase64Safe(responsePayload.signature);
    if (sigBytes.length != 64) {
      throw HandshakeValidationException('Signature must be exactly 64 bytes.');
    }

    bool isSignatureValid;
    try {
      isSignatureValid = await _ed25519.verify(
        responsePayload.toSignableBytes(),
        signature: Signature(sigBytes, publicKey: peerIdentityPublicKey),
      );
    } catch (e) {
      throw HandshakeValidationException('Signature verification failed: $e');
    }

    if (!isSignatureValid) {
      throw HandshakeValidationException(
        'Invalid Ed25519 signature on HandshakeResponse from ${responsePayload.senderNodeId}.',
      );
    }

    final pendingEphemeralPublicKey = await pending.ephemeralKeyPair
        .extractPublicKey();
    final expectedPeerEcho = base64Encode(pendingEphemeralPublicKey.bytes);
    if (responsePayload.peerEphemeralPublicKey != expectedPeerEcho) {
      throw HandshakeValidationException(
        'Handshake response peer ephemeral key does not match pending ephemeral key.',
      );
    }

    final peerEphemeralPublicKey = SimplePublicKey(
      base64Decode(responsePayload.ephemeralPublicKey),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: pending.ephemeralKeyPair,
      remotePublicKey: peerEphemeralPublicKey,
    );

    final sessionKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: _sessionSalt,
      info: _sessionInfo,
    );

    final sessionKeyBytes = await sessionKey.extractBytes();
    final hash = await Sha256().hash(sessionKeyBytes);
    final sessionFingerprint = _bytesToHex(hash.bytes).substring(0, 16);

    final session = SecureSession(
      sessionId: 'sess-${DateTime.now().microsecondsSinceEpoch}',
      peerNodeId: responsePayload.senderNodeId,
      peerIdentityPublicKey: responsePayload.senderIdentityPublicKey,
      sessionKey: sessionKey,
      sessionFingerprint: sessionFingerprint,
      establishedAt: DateTime.now().toUtc(),
    );

    _sessions[responsePayload.senderNodeId] = session;
    _pendingHandshakes.remove(responsePayload.senderNodeId);

    return session;
  }

  Future<EncryptedPayload> encrypt({
    required String peerNodeId,
    required String plaintext,
    required String messageId,
    required String senderNodeId,
    required String recipientNodeId,
  }) async {
    final session = _sessions[peerNodeId];
    if (session == null) {
      throw SessionNotFoundException(
        'Cannot encrypt: No active secure session for peer $peerNodeId.',
      );
    }

    final sequenceNumber = session.nextOutboundSequenceNumber();
    final aad = utf8.encode(
      '$messageId:$senderNodeId:$recipientNodeId:$sequenceNumber',
    );

    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: session.sessionKey,
      aad: aad,
    );

    return EncryptedPayload.fromSecretBox(
      secretBox: secretBox,
      sequenceNumber: sequenceNumber,
      sessionFingerprint: session.sessionFingerprint,
    );
  }

  Future<String> decrypt({
    required String peerNodeId,
    required EncryptedPayload encryptedPayload,
    required String messageId,
    required String senderNodeId,
    required String recipientNodeId,
  }) async {
    final session = _sessions[peerNodeId];
    if (session == null) {
      throw SessionNotFoundException(
        'Cannot decrypt: No active secure session for peer $peerNodeId.',
      );
    }

    if (encryptedPayload.sessionFingerprint != session.sessionFingerprint) {
      throw DecryptionAuthenticationException(
        'Session fingerprint mismatch: expected ${session.sessionFingerprint}, got ${encryptedPayload.sessionFingerprint}.',
      );
    }

    if (!session.isValidInboundSequence(encryptedPayload.sequenceNumber)) {
      throw ReplayAttackException(
        'Replay attack detected: inbound sequence ${encryptedPayload.sequenceNumber} <= last received ${session.lastInboundSequenceNumber}.',
      );
    }

    final aad = utf8.encode(
      '$messageId:$senderNodeId:$recipientNodeId:${encryptedPayload.sequenceNumber}',
    );

    try {
      final decryptedBytes = await _aesGcm.decrypt(
        encryptedPayload.toSecretBox(),
        secretKey: session.sessionKey,
        aad: aad,
      );

      session.updateInboundSequence(encryptedPayload.sequenceNumber);
      return utf8.decode(decryptedBytes);
    } catch (e) {
      if (e is SecureSessionException) {
        rethrow;
      }
      throw DecryptionAuthenticationException(
        'Decryption or authentication failed: $e',
      );
    }
  }

  static List<int> _decodeBase64Safe(String encoded) {
    try {
      return base64Decode(encoded);
    } catch (e) {
      throw HandshakeValidationException('Invalid base64 encoding: $e');
    }
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hexToBytes(String hex) {
    if (hex.length.isOdd) {
      throw FormatException('Hex string must have an even length.');
    }
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
