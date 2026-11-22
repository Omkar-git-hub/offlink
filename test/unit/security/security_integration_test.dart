import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/drift_peer_security_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/domain/security/flood_rate_limiter.dart';
import 'package:offlink/domain/security/trust_status.dart';

class _FakeMemoryTransport implements PacketTransport {
  final StreamController<OfflinkPacket> _incomingController =
      StreamController<OfflinkPacket>.broadcast();
  final List<OfflinkPacket> sentPackets = [];

  @override
  Stream<OfflinkPacket> get incomingPackets => _incomingController.stream;

  @override
  List<String> get connectedPeerIds => const ['peer-bob', 'spammer-node'];

  void emitInbound(OfflinkPacket packet) {
    _incomingController.add(packet);
  }

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    sentPackets.add(packet);
  }

  void dispose() {
    _incomingController.close();
  }
}

class _StubIdentityManager implements IdentityManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  OfflinkIdentity? get currentIdentity => OfflinkIdentity(
    nodeId: 'local-alice',
    username: 'Alice',
    publicKey: 'alice-pubkey',
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('Security Integration Tests', () {
    late OfflinkDatabase database;
    late DriftPeerSecurityRepository securityRepo;
    late DriftMessageRepository messageRepo;
    late DriftConversationRepository conversationRepo;
    late FloodRateLimiter floodLimiter;
    late _FakeMemoryTransport underlyingTransport;
    late MeshPacketRouter router;
    late DirectMessageService messageService;

    setUp(() {
      database = OfflinkDatabase.forTesting(NativeDatabase.memory());
      securityRepo = DriftPeerSecurityRepository(database);
      messageRepo = DriftMessageRepository(database);
      conversationRepo = DriftConversationRepository(database);

      floodLimiter = FloodRateLimiter(
        maxPacketsPerWindow: 3,
        windowDuration: const Duration(seconds: 1),
        quarantineThreshold: 2,
        quarantineDuration: const Duration(seconds: 5),
      );

      underlyingTransport = _FakeMemoryTransport();

      router = MeshPacketRouter(
        transport: underlyingTransport,
        getLocalNodeId: () => 'local-alice',
        isPeerBlocked: securityRepo.isPeerBlocked,
        floodRateLimiter: floodLimiter,
      );

      messageService = DirectMessageService(
        packetTransport: router,
        identityManager: _StubIdentityManager(),
        messageRepository: messageRepo,
        conversationRepository: conversationRepo,
        peerSecurityRepository: securityRepo,
      );
    });

    tearDown(() async {
      messageService.dispose();
      router.dispose();
      underlyingTransport.dispose();
      securityRepo.dispose();
      await database.close();
    });

    test(
      'Router drops inbound packets from blocked peers at ingress',
      () async {
        await securityRepo.blockPeer('node-bad', reason: 'abuse');

        final inboundPackets = <OfflinkPacket>[];
        final sub = router.incomingPackets.listen(inboundPackets.add);

        final packetFromBlocked = OfflinkPacket(
          messageId: 'pkt-blocked-1',
          senderNodeId: 'node-bad',
          recipientNodeId: 'local-alice',
          messageType: OfflinkMessageType.text,
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
          payload: 'spam payload',
        );

        underlyingTransport.emitInbound(packetFromBlocked);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          inboundPackets,
          isEmpty,
          reason: 'Packet from blocked peer must be dropped',
        );

        // Unblock node-bad and verify subsequent packet is received
        await securityRepo.unblockPeer('node-bad');
        final packetAllowed = packetFromBlocked.copyWith(
          messageId: 'pkt-allowed-1',
        );
        underlyingTransport.emitInbound(packetAllowed);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(inboundPackets, hasLength(1));
        expect(inboundPackets.first.messageId, equals('pkt-allowed-1'));

        await sub.cancel();
      },
    );

    test(
      'Router prevents forwarding packets originating from blocked peers',
      () async {
        await securityRepo.blockPeer('node-malicious');

        final forwardPacket = OfflinkPacket(
          messageId: 'fwd-1',
          senderNodeId: 'node-malicious',
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.text,
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
          payload: 'relayed spam',
        );

        underlyingTransport.emitInbound(forwardPacket);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          underlyingTransport.sentPackets,
          isEmpty,
          reason:
              'Router must drop forwarded packets originating from blocked peers',
        );
      },
    );

    test(
      'Inbound flood rate limiting drops packets and triggers quarantine backoff',
      () async {
        final inbound = <OfflinkPacket>[];
        final sub = router.incomingPackets.listen(inbound.add);

        final now = DateTime.utc(2026, 11, 23, 10, 0, 0);

        // Send 3 packets (maxPacketsPerWindow = 3)
        for (var i = 1; i <= 3; i++) {
          underlyingTransport.emitInbound(
            OfflinkPacket(
              messageId: 'flood-$i',
              senderNodeId: 'spammer-node',
              recipientNodeId: 'local-alice',
              messageType: OfflinkMessageType.text,
              timestamp: now,
              ttl: 3,
              payload: 'flood-$i',
            ),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(inbound, hasLength(3));

        // 4th packet in window -> dropped by rate limiter
        underlyingTransport.emitInbound(
          OfflinkPacket(
            messageId: 'flood-4',
            senderNodeId: 'spammer-node',
            recipientNodeId: 'local-alice',
            messageType: OfflinkMessageType.text,
            timestamp: now,
            ttl: 3,
            payload: 'flood-4',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          inbound,
          hasLength(3),
          reason: '4th packet exceeded window limit',
        );

        // 5th packet -> violation 2 -> reaches quarantineThreshold (2) -> quarantined!
        underlyingTransport.emitInbound(
          OfflinkPacket(
            messageId: 'flood-5',
            senderNodeId: 'spammer-node',
            recipientNodeId: 'local-alice',
            messageType: OfflinkMessageType.text,
            timestamp: now,
            ttl: 3,
            payload: 'flood-5',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(inbound, hasLength(3));
        expect(floodLimiter.isQuarantined('spammer-node'), isTrue);

        await sub.cancel();
      },
    );

    test(
      'DirectMessageService rejects sending messages to blocked peers',
      () async {
        await securityRepo.blockPeer('node-blocked-target');

        expect(
          () => messageService.sendMessage(
            peerId: 'node-blocked-target',
            recipientNodeId: 'node-blocked-target',
            content: 'Hello blocked user',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Cannot send message to blocked peer'),
            ),
          ),
        );
      },
    );

    test(
      'DirectMessageService detects public key mismatch and flags TrustStatus.mismatched',
      () async {
        final now = DateTime.utc(2026, 11, 23, 12, 0);

        // 1. Establish verified trust with Bob's legitimate public key
        await securityRepo.saveOrUpdatePeerTrust(
          PeerTrust(
            peerNodeId: 'peer-bob',
            peerPublicKey: 'bob-legitimate-public-key-hex',
            safetyFingerprint:
                '11111 22222 33333 44444 55555 66666 77777 88888 99999 00000 11111 22222',
            trustStatus: TrustStatus.verified,
            verifiedAt: now,
            updatedAt: now,
          ),
        );

        final trustBefore = await securityRepo.getPeerTrust('peer-bob');
        expect(trustBefore!.trustStatus, equals(TrustStatus.verified));

        // 2. Mallory attempts MITM key substitution for peer-bob
        // DirectMessageService receives a HandshakeInit from peer-bob with a forged key
        final mitmHandshakeInitPacket = OfflinkPacket(
          messageId: 'mitm-init-1',
          senderNodeId: 'peer-bob',
          recipientNodeId: 'local-alice',
          messageType: OfflinkMessageType.handshakeInit,
          timestamp: now,
          ttl: 3,
          payload:
              '{"senderNodeId":"peer-bob","senderIdentityPublicKey":"forged-mallory-public-key","ephemeralPublicKey":"ephem-key","timestamp":"${now.toIso8601String()}","signature":"fakesig"}',
        );

        underlyingTransport.emitInbound(mitmHandshakeInitPacket);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // 3. Trust status for peer-bob must now be mismatched!
        final trustAfter = await securityRepo.getPeerTrust('peer-bob');
        expect(trustAfter, isNotNull);
        expect(trustAfter!.trustStatus, equals(TrustStatus.mismatched));
        expect(trustAfter.isMismatched, isTrue);
      },
    );
  });
}
