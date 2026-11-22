import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/crypto/session/encrypted_payload.dart';
import 'package:offlink/crypto/session/handshake_payload.dart';
import 'package:offlink/domain/location/location_payload.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/protocol/group_message_payload.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_validator.dart';
import 'package:offlink/domain/protocol/protocol_version.dart';

class _FakePacketTransport implements PacketTransport {
  final List<OfflinkPacket> sentPackets = [];

  @override
  List<String> get connectedPeerIds => const [];

  @override
  Stream<OfflinkPacket> get incomingPackets => const Stream.empty();

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    sentPackets.add(packet);
  }

  void dispose() {}
}

void main() {
  group('Protocol Fuzzing Suite', () {
    const validator = PacketValidator();
    final random = Random(42);

    group('OfflinkPacket.decode & fromMap Fuzzing', () {
      test('safely rejects completely random binary and string garbage', () {
        final garbageInputs = [
          '',
          '   ',
          'null',
          '12345',
          'true',
          '["not", "a", "map"]',
          '{malformed json',
          '{"version": 1',
          '\x00\x01\x02\xFF\xFE\xFD',
          '{"messageId": 123}', // wrong type
          '{"version": "one"}', // wrong type
          jsonEncode({'version': 1, 'messageId': null}),
        ];

        for (final input in garbageInputs) {
          expect(
            () => OfflinkPacket.decode(input),
            throwsA(anything),
            reason: 'Should fail parsing garbage input: "$input"',
          );
        }
      });

      test(
        'safely rejects maps with missing required fields or unknown message types',
        () {
          final baseValid = {
            'version': 1,
            'messageId': 'msg-1',
            'senderNodeId': 'node-a',
            'recipientNodeId': 'node-b',
            'messageType': 'text',
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'ttl': 3,
            'payload': 'hello',
          };

          // Missing each key one by one
          for (final key in baseValid.keys) {
            final copy = Map<String, dynamic>.from(baseValid)..remove(key);
            expect(
              () => OfflinkPacket.fromMap(copy),
              throwsA(anything),
              reason: 'Should fail when missing key: $key',
            );
          }

          // Invalid message type
          final invalidType = Map<String, dynamic>.from(baseValid)
            ..['messageType'] = 'unknown_future_type';
          expect(
            () => OfflinkPacket.fromMap(invalidType),
            throwsFormatException,
          );

          // Invalid timestamp format
          final invalidTime = Map<String, dynamic>.from(baseValid)
            ..['timestamp'] = 'not-a-date';
          expect(
            () => OfflinkPacket.fromMap(invalidTime),
            throwsFormatException,
          );
        },
      );
    });

    group('PacketValidator Boundary & Fuzzing', () {
      OfflinkPacket createPacket({
        int version = ProtocolVersion.current,
        String messageId = 'valid-id',
        String senderNodeId = 'sender-node',
        String recipientNodeId = 'recipient-node',
        OfflinkMessageType messageType = OfflinkMessageType.text,
        DateTime? timestamp,
        int ttl = 4,
        String payload = 'valid payload',
      }) {
        return OfflinkPacket(
          version: version,
          messageId: messageId,
          senderNodeId: senderNodeId,
          recipientNodeId: recipientNodeId,
          messageType: messageType,
          timestamp: timestamp ?? DateTime.now().toUtc(),
          ttl: ttl,
          payload: payload,
        );
      }

      test('validates standard well-formed packet', () {
        final pkt = createPacket();
        expect(validator.isValid(pkt), isTrue);
      });

      test('rejects boundary violations', () {
        // Version mismatch
        expect(validator.isValid(createPacket(version: 999)), isFalse);
        expect(validator.isValid(createPacket(version: -1)), isFalse);

        // Empty / whitespace identifiers
        expect(validator.isValid(createPacket(messageId: '')), isFalse);
        expect(validator.isValid(createPacket(messageId: '   ')), isFalse);
        expect(validator.isValid(createPacket(senderNodeId: '')), isFalse);
        expect(validator.isValid(createPacket(senderNodeId: '  \t ')), isFalse);
        expect(validator.isValid(createPacket(recipientNodeId: '')), isFalse);
        expect(
          validator.isValid(createPacket(recipientNodeId: '  \n ')),
          isFalse,
        );

        // Negative or excessive TTL
        expect(validator.isValid(createPacket(ttl: -1)), isFalse);
        expect(validator.isValid(createPacket(ttl: -100)), isFalse);
        expect(
          validator.isValid(createPacket(ttl: 17)),
          isFalse,
        ); // default max is 16
        expect(validator.isValid(createPacket(ttl: 999999)), isFalse);

        // Oversized payload (> 4096 bytes)
        final oversized = 'X' * 4097;
        expect(validator.isValid(createPacket(payload: oversized)), isFalse);
      });
    });

    group('Payload Decoders Fuzzing', () {
      test(
        'EncryptedPayload.fromMap rejects corrupted maps and malformed base64',
        () {
          final invalidMaps = [
            <String, dynamic>{},
            {'ciphertext': 'abc'}, // missing nonce, mac, etc.
            {
              'ciphertext': 'abc',
              'nonce': '123',
              'mac': 'xyz',
              'sequenceNumber': 'not-an-int',
              'sessionFingerprint': 'fp',
            },
          ];

          for (final m in invalidMaps) {
            expect(() => EncryptedPayload.fromMap(m), throwsA(anything));
          }

          // Malformed base64 strings when calling toSecretBox
          final badBase64Payload = EncryptedPayload(
            ciphertext: '???not-base64???',
            nonce: 'invalid!!!',
            mac: 'bad@@@',
            sequenceNumber: 1,
            sessionFingerprint: 'test-session',
          );
          expect(() => badBase64Payload.toSecretBox(), throwsFormatException);
        },
      );

      test(
        'HandshakeInitPayload & HandshakeResponsePayload reject missing fields and bad formats',
        () {
          expect(() => HandshakeInitPayload.fromMap({}), throwsA(anything));
          expect(() => HandshakeResponsePayload.fromMap({}), throwsA(anything));

          final partialInit = {
            'senderNodeId': 'node-1',
            'senderIdentityPublicKey': 'pub-1',
            // missing ephemeralPublicKey, timestamp, signature
          };
          expect(
            () => HandshakeInitPayload.fromMap(partialInit),
            throwsA(anything),
          );
        },
      );

      test('LocationPayload rejects missing or malformed fields', () {
        expect(() => LocationPayload.decode('not json'), throwsFormatException);
        expect(() => LocationPayload.fromMap({}), throwsA(anything));

        final malformedPayloadMap = {
          'sharingType': 'unknown_sharing_type',
          'latitude': 45.0,
          'longitude': -73.0,
          'accuracyMeters': 5.0,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        };
        expect(
          () => LocationPayload.fromMap(malformedPayloadMap),
          throwsA(anything),
        );
      });

      test('GroupMessagePayload rejects missing or wrong type fields', () {
        expect(() => GroupMessagePayload.fromMap({}), throwsA(anything));

        final invalidTimeMap = {
          'messageId': 'm-1',
          'groupId': 'g-1',
          'groupName': 'Group 1',
          'senderNodeId': 'n-1',
          'senderDisplayName': 'User 1',
          'content': 'hello',
          'timestamp': 'unparseable',
        };
        expect(
          () => GroupMessagePayload.fromMap(invalidTimeMap),
          throwsFormatException,
        );
      });
    });

    group('MeshPacketRouter Ingress Fuzzing Resilience', () {
      test(
        'processes 100 randomly mutated packets without unhandled exceptions or crashes',
        () async {
          final transport = _FakePacketTransport();
          final router = MeshPacketRouter(
            transport: transport,
            getLocalNodeId: () => 'router-node-local',
            isPeerBlocked: (id) => id == 'blocked-peer-node',
          );

          final messageTypes = OfflinkMessageType.values;

          for (var i = 0; i < 100; i++) {
            final isBlocked = random.nextBool();
            final sender = isBlocked
                ? 'blocked-peer-node'
                : 'node-${random.nextInt(100)}';
            final recipient = random.nextBool()
                ? 'router-node-local'
                : 'destination-${random.nextInt(100)}';
            final type = messageTypes[random.nextInt(messageTypes.length)];
            final ttl = random.nextInt(20) - 5; // can be negative or large
            final payloadLength = random.nextInt(5000);
            final payload = 'FuzzPayload-${'A' * payloadLength}';

            final packet = OfflinkPacket(
              messageId: 'fuzz-msg-$i-${random.nextInt(999999)}',
              senderNodeId: sender,
              recipientNodeId: recipient,
              messageType: type,
              timestamp: DateTime.now().toUtc().add(
                Duration(minutes: random.nextInt(200) - 100),
              ),
              ttl: ttl,
              payload: payload,
            );

            // Simulate incoming packet routing
            expect(
              () => router.sendPacket(peerId: 'any-peer', packet: packet),
              returnsNormally,
            );
          }

          router.dispose();
        },
      );
    });
  });
}
