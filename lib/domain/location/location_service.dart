// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../crypto/session/encrypted_payload.dart';
import '../../crypto/session/secure_session_service.dart';
import '../group/group_repository.dart';
import '../identity/identity_manager.dart';
import '../messaging/chat_message.dart';
import '../messaging/conversation.dart';
import '../messaging/conversation_repository.dart';
import '../messaging/message_repository.dart';
import '../protocol/offlink_message_type.dart';
import '../protocol/offlink_packet.dart';
import '../protocol/packet_transport.dart';
import 'live_location_session.dart';
import 'location_payload.dart';
import 'location_provider.dart';
import 'position_data.dart';

/// Service coordinating offline, privacy-preserving location sharing over BLE and mesh networks.
class LocationService {
  LocationService({
    required LocationProvider locationProvider,
    required PacketTransport packetTransport,
    required IdentityManager identityManager,
    SecureSessionService? secureSessionService,
    MessageRepository? messageRepository,
    ConversationRepository? conversationRepository,
    GroupRepository? groupRepository,
    Duration updateInterval = const Duration(seconds: 30),
  }) : _locationProvider = locationProvider,
       _packetTransport = packetTransport,
       _identityManager = identityManager,
       _secureSessionService = secureSessionService,
       _messageRepository = messageRepository,
       _conversationRepository = conversationRepository,
       _groupRepository = groupRepository,
       _updateInterval = updateInterval {
    _subscription = _packetTransport.incomingPackets.listen(
      _handleIncomingPacket,
    );
    _startPeriodicTimer();
  }

  final LocationProvider _locationProvider;
  final PacketTransport _packetTransport;
  final IdentityManager _identityManager;
  final SecureSessionService? _secureSessionService;
  final MessageRepository? _messageRepository;
  final ConversationRepository? _conversationRepository;
  final GroupRepository? _groupRepository;
  final Duration _updateInterval;

  final StreamController<LocationPayload> _incomingLocationsController =
      StreamController<LocationPayload>.broadcast();
  final StreamController<ChatMessage> _incomingLocationMessagesController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatMessage> _locationMessagesController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<List<LiveLocationSession>>
  _activeSessionsStreamController =
      StreamController<List<LiveLocationSession>>.broadcast();

  StreamSubscription<OfflinkPacket>? _subscription;
  Timer? _periodicTimer;

  // Active outgoing live sessions initiated by the local user: targetId -> session
  final Map<String, LiveLocationSession> _activeLiveSessions = {};

  // Delivery status tracking per recipient / packetId -> messageId
  final Map<String, String> _packetToMessageMap = {};
  final Map<String, Map<String, ChatMessageStatus>> _deliveryStatuses = {};

  bool _isBackgrounded = false;

  /// Stream of validated incoming location payloads.
  Stream<LocationPayload> get incomingLocations =>
      _incomingLocationsController.stream;

  /// Stream of persisted incoming location chat messages.
  Stream<ChatMessage> get incomingLocationMessages =>
      _incomingLocationMessagesController.stream;

  /// Stream of all location chat messages (incoming and outgoing).
  Stream<ChatMessage> get locationMessages =>
      _locationMessagesController.stream;

  /// Stream of active outgoing live sessions list.
  Stream<List<LiveLocationSession>> get activeSessionsStream =>
      _activeSessionsStreamController.stream;

  /// List of active outgoing live sessions.
  List<LiveLocationSession> get activeLiveSessions =>
      List.unmodifiable(_activeLiveSessions.values.toList());

  /// Checks whether location hardware/services are enabled.
  Future<bool> isLocationServiceEnabled() =>
      _locationProvider.isLocationServiceEnabled();

  /// Checks current permission status without prompting.
  Future<LocationPermissionStatus> checkPermission() =>
      _locationProvider.checkPermission();

  /// Prompts user for location permission.
  Future<LocationPermissionStatus> requestPermission() =>
      _locationProvider.requestPermission();

  /// Gets the active live session for [targetId] (peerId or groupId) if one exists.
  LiveLocationSession? getActiveLiveSession(String targetId) =>
      _activeLiveSessions[targetId];

  /// Checks if live location sharing is active with [targetId].
  bool isLiveLocationActive(String targetId) =>
      _activeLiveSessions.containsKey(targetId) &&
      !_activeLiveSessions[targetId]!.isExpired();

  /// Updates app background state to throttle/pause GPS tracking when backgrounded.
  void setBackgroundState(bool isBackgrounded) {
    _isBackgrounded = isBackgrounded;
  }

  /// Shares a one-time location snapshot with [targetId] (peerNodeId or groupId).
  Future<ChatMessage> sendOneTimeLocation({
    required String targetId,
    required bool isGroup,
    String? peerId,
  }) async {
    final position = await _locationProvider.getCurrentPosition();
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final username = _identityManager.currentIdentity?.username ?? 'Me';
    final now = DateTime.now().toUtc();
    final messageId = 'loc-snap-${now.microsecondsSinceEpoch}';

    final payload = LocationPayload(
      locationId: messageId,
      senderNodeId: localNodeId,
      senderDisplayName: username,
      recipientNodeId: isGroup ? null : targetId,
      groupId: isGroup ? targetId : null,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: now,
      sharingType: LocationSharingType.oneTime,
      isLive: false,
    );

    final conversationId = isGroup ? 'group-$targetId' : targetId;
    final chatMessage = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      senderNodeId: localNodeId,
      recipientNodeId: targetId,
      content: payload.encode(),
      timestamp: now,
      isOutgoing: true,
      status: ChatMessageStatus.sent,
    );

    // 1. Upsert conversation
    await _updateConversationRecord(
      conversationId: conversationId,
      targetId: targetId,
      isGroup: isGroup,
      lastMessage: '📍 Location snapshot',
      timestamp: now,
    );

    // 2. Persist message
    if (_messageRepository != null) {
      await _messageRepository.saveMessage(
        chatMessage,
        conversationId: conversationId,
      );
    }
    _locationMessagesController.add(chatMessage);

    // 3. Transmit packet(s)
    if (isGroup) {
      await _fanoutGroupLocationPayload(
        groupId: targetId,
        payload: payload,
        messageId: messageId,
      );
    } else {
      await _sendDirectLocationPayload(
        targetNodeId: targetId,
        peerId: peerId ?? targetId,
        payload: payload,
        messageId: messageId,
      );
    }

    return chatMessage;
  }

  /// Starts live location sharing with [targetId] (peerId or groupId) for [duration].
  Future<LiveLocationSession> startLiveLocation({
    required String targetId,
    required bool isGroup,
    required Duration duration,
    String? peerId,
  }) async {
    final position = await _locationProvider.getCurrentPosition();
    final now = DateTime.now().toUtc();
    final sessionId = 'live-${now.microsecondsSinceEpoch}';
    final expiresAt = now.add(duration);

    final session = LiveLocationSession(
      id: sessionId,
      targetId: targetId,
      isGroup: isGroup,
      startedAt: now,
      duration: duration,
      expiresAt: expiresAt,
      isActive: true,
      lastPosition: position,
      lastSentAt: now,
    );

    _activeLiveSessions[targetId] = session;
    _activeSessionsStreamController.add(activeLiveSessions);

    // Send initial update
    await _sendLiveUpdateForSession(session, position, now);

    return session;
  }

  /// Stops an active live location sharing session with [targetId].
  Future<void> stopLiveLocation(
    String targetId, {
    bool sendStopPacket = true,
  }) async {
    final session = _activeLiveSessions.remove(targetId);
    if (session == null) {
      return;
    }

    _activeSessionsStreamController.add(activeLiveSessions);

    if (sendStopPacket) {
      final localNodeId =
          _identityManager.currentIdentity?.nodeId ?? 'local-node';
      final username = _identityManager.currentIdentity?.username ?? 'Me';
      final now = DateTime.now().toUtc();
      final stopMessageId = 'loc-stop-${now.microsecondsSinceEpoch}';

      final payload = LocationPayload(
        locationId: stopMessageId,
        senderNodeId: localNodeId,
        senderDisplayName: username,
        recipientNodeId: session.isGroup ? null : targetId,
        groupId: session.isGroup ? targetId : null,
        latitude: session.lastPosition?.latitude ?? 0.0,
        longitude: session.lastPosition?.longitude ?? 0.0,
        accuracy: session.lastPosition?.accuracy,
        timestamp: now,
        sharingType: LocationSharingType.liveStop,
        liveSessionId: session.id,
        isLive: false,
      );

      final conversationId = session.isGroup ? 'group-$targetId' : targetId;
      final liveMessageId = 'loc-live-${session.id}';

      // Update existing live message in repository to show stopped
      final existingMsg = await _messageRepository?.getMessageById(
        liveMessageId,
      );
      if (existingMsg != null) {
        final updatedMsg = existingMsg.copyWith(content: payload.encode());
        await _messageRepository?.saveMessage(
          updatedMsg,
          conversationId: conversationId,
        );
        _locationMessagesController.add(updatedMsg);
      }

      await _updateConversationRecord(
        conversationId: conversationId,
        targetId: targetId,
        isGroup: session.isGroup,
        lastMessage: '📍 Live location ended',
        timestamp: now,
      );

      if (session.isGroup) {
        await _fanoutGroupLocationPayload(
          groupId: targetId,
          payload: payload,
          messageId: stopMessageId,
        );
      } else {
        await _sendDirectLocationPayload(
          targetNodeId: targetId,
          peerId: targetId,
          payload: payload,
          messageId: stopMessageId,
        );
      }
    }
  }

  Future<void> _sendLiveUpdateForSession(
    LiveLocationSession session,
    PositionData position,
    DateTime timestamp,
  ) async {
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final username = _identityManager.currentIdentity?.username ?? 'Me';
    final liveMessageId = 'loc-live-${session.id}';

    final payload = LocationPayload(
      locationId: 'loc-upd-${timestamp.microsecondsSinceEpoch}',
      senderNodeId: localNodeId,
      senderDisplayName: username,
      recipientNodeId: session.isGroup ? null : session.targetId,
      groupId: session.isGroup ? session.targetId : null,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: timestamp,
      expiresAt: session.expiresAt,
      sharingType: LocationSharingType.liveUpdate,
      liveSessionId: session.id,
      isLive: true,
    );

    final conversationId = session.isGroup
        ? 'group-${session.targetId}'
        : session.targetId;

    // Upsert conversation
    await _updateConversationRecord(
      conversationId: conversationId,
      targetId: session.targetId,
      isGroup: session.isGroup,
      lastMessage: '📍 Live location sharing',
      timestamp: timestamp,
    );

    // Save/update live message in-place
    final chatMessage = ChatMessage(
      id: liveMessageId,
      conversationId: conversationId,
      senderNodeId: localNodeId,
      recipientNodeId: session.targetId,
      content: payload.encode(),
      timestamp: timestamp,
      isOutgoing: true,
      status: ChatMessageStatus.sent,
    );

    if (_messageRepository != null) {
      await _messageRepository.saveMessage(
        chatMessage,
        conversationId: conversationId,
      );
    }
    _locationMessagesController.add(chatMessage);

    if (session.isGroup) {
      await _fanoutGroupLocationPayload(
        groupId: session.targetId,
        payload: payload,
        messageId: liveMessageId,
      );
    } else {
      await _sendDirectLocationPayload(
        targetNodeId: session.targetId,
        peerId: session.targetId,
        payload: payload,
        messageId: liveMessageId,
      );
    }

    _activeLiveSessions[session.targetId] = session.copyWith(
      lastPosition: position,
      lastSentAt: timestamp,
    );
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final now = DateTime.now().toUtc();
      final expiredKeys = <String>[];

      for (final entry in _activeLiveSessions.entries) {
        final session = entry.value;
        if (session.isExpired(now)) {
          expiredKeys.add(entry.key);
          continue;
        }

        // Throttle updates: skip if app is backgrounded or interval has not elapsed
        if (_isBackgrounded) {
          continue;
        }

        final lastSent = session.lastSentAt ?? session.startedAt;
        if (now.difference(lastSent) >= _updateInterval) {
          try {
            final position = await _locationProvider.getCurrentPosition();
            await _sendLiveUpdateForSession(session, position, now);
          } catch (_) {
            // Best-effort GPS capture
          }
        }
      }

      for (final key in expiredKeys) {
        await stopLiveLocation(key, sendStopPacket: true);
      }
    });
  }

  Future<void> _sendDirectLocationPayload({
    required String targetNodeId,
    required String peerId,
    required LocationPayload payload,
    required String messageId,
  }) async {
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final payloadString = payload.encode();
    final packetId = 'loc-pkt-${DateTime.now().microsecondsSinceEpoch}';

    String wirePayload;
    if (_secureSessionService != null) {
      if (!_secureSessionService.hasSession(targetNodeId)) {
        // Zero-plaintext enforcement: do not send location in the clear
        throw StateError(
          'No secure session established with peer $targetNodeId. Location transmission rejected.',
        );
      }
      try {
        final encrypted = await _secureSessionService.encrypt(
          peerNodeId: targetNodeId,
          plaintext: payloadString,
          messageId: packetId,
          senderNodeId: localNodeId,
          recipientNodeId: targetNodeId,
        );
        wirePayload = encrypted.encode();
      } catch (e) {
        throw StateError('Failed to encrypt location payload: $e');
      }
    } else {
      wirePayload = payloadString;
    }

    final packet = OfflinkPacket(
      messageId: packetId,
      senderNodeId: localNodeId,
      recipientNodeId: targetNodeId,
      messageType: OfflinkMessageType.location,
      timestamp: payload.timestamp,
      ttl: 4,
      payload: wirePayload,
    );

    _packetToMessageMap[packetId] = messageId;

    try {
      await _packetTransport.sendPacket(peerId: peerId, packet: packet);
    } catch (_) {
      // Mesh/transport queue handles delivery
    }
  }

  Future<void> _fanoutGroupLocationPayload({
    required String groupId,
    required LocationPayload payload,
    required String messageId,
  }) async {
    if (_groupRepository == null) {
      return;
    }

    final members = await _groupRepository.getGroupMembers(groupId);
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final payloadString = payload.encode();

    final memberStatuses = <String, ChatMessageStatus>{};

    for (final member in members) {
      if (member.memberNodeId == localNodeId) {
        continue;
      }

      final packetId =
          'loc-grp-${DateTime.now().microsecondsSinceEpoch}-${member.memberNodeId}';

      String wirePayload;
      if (_secureSessionService != null) {
        if (!_secureSessionService.hasSession(member.memberNodeId)) {
          memberStatuses[member.memberNodeId] = ChatMessageStatus.failed;
          continue;
        }
        try {
          final encrypted = await _secureSessionService.encrypt(
            peerNodeId: member.memberNodeId,
            plaintext: payloadString,
            messageId: packetId,
            senderNodeId: localNodeId,
            recipientNodeId: member.memberNodeId,
          );
          wirePayload = encrypted.encode();
        } catch (_) {
          memberStatuses[member.memberNodeId] = ChatMessageStatus.failed;
          continue;
        }
      } else {
        wirePayload = payloadString;
      }

      final packet = OfflinkPacket(
        messageId: packetId,
        senderNodeId: localNodeId,
        recipientNodeId: member.memberNodeId,
        messageType: OfflinkMessageType.location,
        timestamp: payload.timestamp,
        ttl: 4,
        payload: wirePayload,
      );

      _packetToMessageMap[packetId] = messageId;

      try {
        await _packetTransport.sendPacket(
          peerId: member.memberNodeId,
          packet: packet,
        );
        memberStatuses[member.memberNodeId] = ChatMessageStatus.sent;
      } catch (_) {
        memberStatuses[member.memberNodeId] = ChatMessageStatus.failed;
      }
    }

    _deliveryStatuses[messageId] = memberStatuses;
  }

  Future<void> _handleIncomingPacket(OfflinkPacket packet) async {
    // 1. Process ACKs for location packets
    if (packet.messageType == OfflinkMessageType.acknowledgement) {
      final ackPacketId = packet.payload;
      final originalMessageId = _packetToMessageMap[ackPacketId];
      if (originalMessageId != null) {
        final statuses = _deliveryStatuses[originalMessageId];
        if (statuses != null) {
          statuses[packet.senderNodeId] = ChatMessageStatus.delivered;
          final allDelivered = statuses.values.every(
            (s) => s == ChatMessageStatus.delivered,
          );
          if (allDelivered && _messageRepository != null) {
            await _messageRepository.updateMessageStatus(
              originalMessageId,
              ChatMessageStatus.delivered,
            );
          }
        } else if (_messageRepository != null) {
          await _messageRepository.updateMessageStatus(
            originalMessageId,
            ChatMessageStatus.delivered,
          );
        }
      }
      return;
    }

    if (packet.messageType != OfflinkMessageType.location) {
      return;
    }

    // 2. Decrypt location payload
    String decryptedString;
    if (_secureSessionService != null) {
      try {
        final encryptedPayload = EncryptedPayload.decode(packet.payload);
        decryptedString = await _secureSessionService.decrypt(
          peerNodeId: packet.senderNodeId,
          encryptedPayload: encryptedPayload,
          messageId: packet.messageId,
          senderNodeId: packet.senderNodeId,
          recipientNodeId: packet.recipientNodeId,
        );
      } catch (_) {
        // Discard unauthenticated or replay packet safely without leaking plaintext
        return;
      }
    } else {
      decryptedString = packet.payload;
    }

    LocationPayload payload;
    try {
      payload = LocationPayload.decode(decryptedString);
    } catch (_) {
      return;
    }

    // 3. Security Check: Envelope sender must match inner payload sender
    if (packet.senderNodeId != payload.senderNodeId) {
      return;
    }

    // 4. Security Check: If group location, verify sender and local node are group members
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    if (payload.groupId != null && _groupRepository != null) {
      final group = await _groupRepository.getGroup(payload.groupId!);
      if (group != null) {
        final members = await _groupRepository.getGroupMembers(group.id);
        final isSenderMember = members.any(
          (m) => m.memberNodeId == payload.senderNodeId,
        );
        final isLocalMember = members.any((m) => m.memberNodeId == localNodeId);
        if (!isSenderMember || !isLocalMember) {
          return;
        }
      }
    }

    // 5. Reverse-path ACK back to sender
    final ackPacket = OfflinkPacket(
      messageId: 'ack-${DateTime.now().microsecondsSinceEpoch}',
      senderNodeId: localNodeId,
      recipientNodeId: packet.senderNodeId,
      messageType: OfflinkMessageType.acknowledgement,
      timestamp: DateTime.now().toUtc(),
      ttl: 4,
      payload: packet.messageId,
    );

    try {
      await _packetTransport.sendPacket(
        peerId: packet.senderNodeId,
        packet: ackPacket,
      );
    } catch (_) {}

    // 6. Check expiration
    if (payload.isExpired()) {
      return;
    }

    // 7. Store / Upsert message
    final isGroup = payload.groupId != null;
    final conversationId = isGroup
        ? 'group-${payload.groupId}'
        : payload.senderNodeId;
    final messageId = payload.isLive && payload.liveSessionId != null
        ? 'loc-live-${payload.liveSessionId}'
        : payload.locationId;

    String lastMessageText;
    if (payload.sharingType == LocationSharingType.liveStop) {
      lastMessageText = '📍 Live location ended';
    } else if (payload.isLive) {
      lastMessageText = '📍 Live location sharing';
    } else {
      lastMessageText = '📍 Location snapshot';
    }

    await _updateConversationRecord(
      conversationId: conversationId,
      targetId: isGroup ? payload.groupId! : payload.senderNodeId,
      isGroup: isGroup,
      lastMessage: lastMessageText,
      timestamp: payload.timestamp,
    );

    final chatMessage = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      senderNodeId: payload.senderNodeId,
      recipientNodeId: isGroup ? payload.groupId! : localNodeId,
      content: payload.encode(),
      timestamp: payload.timestamp,
      isOutgoing: false,
      status: ChatMessageStatus.delivered,
    );

    if (_messageRepository != null) {
      await _messageRepository.saveMessage(
        chatMessage,
        conversationId: conversationId,
      );
    }

    _incomingLocationsController.add(payload);
    _incomingLocationMessagesController.add(chatMessage);
    _locationMessagesController.add(chatMessage);
  }

  Future<void> _updateConversationRecord({
    required String conversationId,
    required String targetId,
    required bool isGroup,
    required String lastMessage,
    required DateTime timestamp,
  }) async {
    if (_conversationRepository == null) return;

    final existing = await _conversationRepository.getConversationById(
      conversationId,
    );
    String displayName;
    if (existing != null) {
      displayName = existing.peerDisplayName;
    } else if (isGroup && _groupRepository != null) {
      final grp = await _groupRepository.getGroup(targetId);
      displayName = grp?.name ?? 'Group $targetId';
    } else {
      displayName =
          'Peer ${targetId.length > 8 ? targetId.substring(0, 8) : targetId}';
    }

    final unread = (existing?.unreadCount ?? 0) + 1;
    await _conversationRepository.upsertConversation(
      Conversation(
        id: conversationId,
        peerNodeId: targetId,
        peerDisplayName: displayName,
        lastMessage: lastMessage,
        unreadCount: unread,
        updatedAt: timestamp,
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _periodicTimer?.cancel();
    _incomingLocationsController.close();
    _incomingLocationMessagesController.close();
    _locationMessagesController.close();
    _activeSessionsStreamController.close();
  }
}
