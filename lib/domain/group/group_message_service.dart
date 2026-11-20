// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../crypto/session/encrypted_payload.dart';
import '../../crypto/session/secure_session_service.dart';
import '../identity/identity_manager.dart';
import '../messaging/chat_message.dart';
import '../messaging/conversation.dart';
import '../messaging/conversation_repository.dart';
import '../messaging/message_repository.dart';
import '../protocol/group_message_payload.dart';
import '../protocol/group_membership_payload.dart';
import '../protocol/offlink_message_type.dart';
import '../protocol/offlink_packet.dart';
import '../protocol/packet_transport.dart';
import 'group.dart';
import 'group_member.dart';
import 'group_repository.dart';

/// Service responsible for managing group messaging, group creation,
/// membership changes, and pairwise-encrypted group message fanout over mesh and BLE.
class GroupMessageService {
  GroupMessageService({
    required PacketTransport packetTransport,
    required IdentityManager identityManager,
    required GroupRepository groupRepository,
    MessageRepository? messageRepository,
    ConversationRepository? conversationRepository,
    SecureSessionService? secureSessionService,
  }) : _packetTransport = packetTransport,
       _identityManager = identityManager,
       _groupRepository = groupRepository,
       _messageRepository = messageRepository,
       _conversationRepository = conversationRepository,
       _secureSessionService = secureSessionService {
    _subscription = _packetTransport.incomingPackets.listen(
      _handleIncomingPacket,
    );
  }

  final PacketTransport _packetTransport;
  final IdentityManager _identityManager;
  final GroupRepository _groupRepository;
  final MessageRepository? _messageRepository;
  final ConversationRepository? _conversationRepository;
  final SecureSessionService? _secureSessionService;

  final StreamController<ChatMessage> _incomingGroupMessagesController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<Group> _groupEventsController =
      StreamController<Group>.broadcast();

  StreamSubscription<OfflinkPacket>? _subscription;

  // Delivery status tracking per group member:
  // messageId -> (memberNodeId -> status)
  final Map<String, Map<String, ChatMessageStatus>> _deliveryStatuses = {};
  // packetId -> messageId mapping to resolve reverse-path ACKs
  final Map<String, String> _packetToMessageMap = {};

  Stream<ChatMessage> get incomingGroupMessages =>
      _incomingGroupMessagesController.stream;

  Stream<Group> get groupEvents => _groupEventsController.stream;

  /// Retrieves delivery status of a message per group member.
  Map<String, ChatMessageStatus> getMemberDeliveryStatuses(String messageId) {
    return Map.unmodifiable(_deliveryStatuses[messageId] ?? {});
  }

  /// Checks if a pairwise secure session is established with [peerNodeId].
  bool hasSecureSession(String peerNodeId) {
    return _secureSessionService?.hasSession(peerNodeId) ?? false;
  }

  /// Initiates pairwise secure session handshakes for any group members who do not have an active session.
  Future<void> initiateSecureSessionsForGroup(String groupId) async {
    if (_secureSessionService == null) {
      return;
    }
    final members = await _groupRepository.getGroupMembers(groupId);
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';

    for (final member in members) {
      if (member.memberNodeId == localNodeId) {
        continue;
      }
      if (!_secureSessionService.hasSession(member.memberNodeId)) {
        try {
          final handshakeInit = await _secureSessionService.createHandshakeInit(
            member.memberNodeId,
          );
          final packet = OfflinkPacket(
            messageId:
                'handshake-init-${DateTime.now().microsecondsSinceEpoch}',
            senderNodeId: localNodeId,
            recipientNodeId: member.memberNodeId,
            messageType: OfflinkMessageType.handshakeInit,
            timestamp: DateTime.now().toUtc(),
            ttl: 3,
            payload: handshakeInit.encode(),
          );
          await _packetTransport.sendPacket(
            peerId: member.memberNodeId,
            packet: packet,
          );
        } catch (_) {}
      }
    }
  }

  /// Creates a new group, persists it locally, and sends membership invites to members.
  Future<Group> createGroup({
    required String name,
    required List<GroupMember> initialMembers,
  }) async {
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final localName = _identityManager.currentIdentity?.username ?? 'Me';
    final now = DateTime.now().toUtc();
    final groupId = 'group-${now.microsecondsSinceEpoch}';

    final admin = GroupMember(
      groupId: groupId,
      memberNodeId: localNodeId,
      memberDisplayName: localName,
      role: GroupMemberRole.admin,
      joinedAt: now,
    );

    final membersMap = <String, GroupMember>{localNodeId: admin};
    for (final member in initialMembers) {
      membersMap[member.memberNodeId] = member.copyWith(groupId: groupId);
    }
    final allMembers = membersMap.values.toList();

    final group = Group(
      id: groupId,
      name: name,
      creatorNodeId: localNodeId,
      createdAt: now,
      updatedAt: now,
    );

    await _groupRepository.createGroup(group, allMembers);

    await _conversationRepository?.upsertConversation(
      Conversation(
        id: 'group-$groupId',
        peerNodeId: groupId,
        peerDisplayName: name,
        lastMessage: 'Group created',
        unreadCount: 0,
        updatedAt: now,
      ),
    );

    final payload = GroupMembershipPayload(
      groupId: groupId,
      groupName: name,
      action: 'create',
      adminNodeId: localNodeId,
      targetNodeId: '',
      members: allMembers,
      timestamp: now,
    );

    await _fanoutMembershipPayload(
      groupId: groupId,
      members: allMembers,
      payload: payload,
    );

    _groupEventsController.add(group);
    return group;
  }

  /// Adds a new member to an existing group.
  Future<void> addMember({
    required String groupId,
    required String memberNodeId,
    required String memberDisplayName,
  }) async {
    final group = await _groupRepository.getGroup(groupId);
    if (group == null) {
      throw StateError('Group $groupId not found');
    }

    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final now = DateTime.now().toUtc();
    final newMember = GroupMember(
      groupId: groupId,
      memberNodeId: memberNodeId,
      memberDisplayName: memberDisplayName,
      role: GroupMemberRole.member,
      joinedAt: now,
    );

    await _groupRepository.addMember(groupId, newMember);

    final updatedMembers = await _groupRepository.getGroupMembers(groupId);
    final payload = GroupMembershipPayload(
      groupId: groupId,
      groupName: group.name,
      action: 'add',
      adminNodeId: localNodeId,
      targetNodeId: memberNodeId,
      members: updatedMembers,
      timestamp: now,
    );

    await _fanoutMembershipPayload(
      groupId: groupId,
      members: updatedMembers,
      payload: payload,
    );
  }

  /// Removes a member from an existing group.
  Future<void> removeMember({
    required String groupId,
    required String memberNodeId,
  }) async {
    final group = await _groupRepository.getGroup(groupId);
    if (group == null) {
      throw StateError('Group $groupId not found');
    }

    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final now = DateTime.now().toUtc();

    await _groupRepository.removeMember(groupId, memberNodeId);

    final remainingMembers = await _groupRepository.getGroupMembers(groupId);
    final payload = GroupMembershipPayload(
      groupId: groupId,
      groupName: group.name,
      action: 'remove',
      adminNodeId: localNodeId,
      targetNodeId: memberNodeId,
      members: remainingMembers,
      timestamp: now,
    );

    await _fanoutMembershipPayload(
      groupId: groupId,
      members: remainingMembers,
      payload: payload,
    );
  }

  /// Sends a group message to all active group members using pairwise encrypted fanout.
  Future<ChatMessage> sendGroupMessage({
    required String groupId,
    required String content,
  }) async {
    final group = await _groupRepository.getGroup(groupId);
    if (group == null) {
      throw StateError('Group $groupId not found');
    }

    final members = await _groupRepository.getGroupMembers(groupId);
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final localName = _identityManager.currentIdentity?.username ?? 'Me';
    final now = DateTime.now().toUtc();
    final messageId = 'msg-${now.microsecondsSinceEpoch}';

    final chatMessage = ChatMessage(
      id: messageId,
      conversationId: 'group-$groupId',
      senderNodeId: localNodeId,
      recipientNodeId: groupId,
      content: content,
      timestamp: now,
      isOutgoing: true,
      status: ChatMessageStatus.sent,
    );

    await _conversationRepository?.upsertConversation(
      Conversation(
        id: 'group-$groupId',
        peerNodeId: groupId,
        peerDisplayName: group.name,
        lastMessage: content,
        unreadCount: 0,
        updatedAt: now,
      ),
    );
    await _messageRepository?.saveMessage(
      chatMessage,
      conversationId: 'group-$groupId',
    );

    final memberStatuses = <String, ChatMessageStatus>{};
    final payload = GroupMessagePayload(
      messageId: messageId,
      groupId: groupId,
      groupName: group.name,
      senderNodeId: localNodeId,
      senderDisplayName: localName,
      content: content,
      timestamp: now,
    );
    final payloadStr = payload.encode();

    for (final member in members) {
      if (member.memberNodeId == localNodeId) {
        continue;
      }

      memberStatuses[member.memberNodeId] = ChatMessageStatus.sending;
      final packetId = '$messageId-${member.memberNodeId}';
      _packetToMessageMap[packetId] = messageId;

      String wirePayload;
      if (_secureSessionService != null) {
        if (!_secureSessionService.hasSession(member.memberNodeId)) {
          // Strict privacy preservation: never transmit group message in plaintext
          // when a cryptographic session service is configured.
          memberStatuses[member.memberNodeId] = ChatMessageStatus.failed;
          continue;
        }
        try {
          final encrypted = await _secureSessionService.encrypt(
            peerNodeId: member.memberNodeId,
            plaintext: payloadStr,
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
        wirePayload = payloadStr;
      }

      final packet = OfflinkPacket(
        messageId: packetId,
        senderNodeId: localNodeId,
        recipientNodeId: member.memberNodeId,
        messageType: OfflinkMessageType.groupMessage,
        timestamp: now,
        ttl: 4,
        payload: wirePayload,
      );

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
    return chatMessage;
  }

  Future<void> _fanoutMembershipPayload({
    required String groupId,
    required List<GroupMember> members,
    required GroupMembershipPayload payload,
  }) async {
    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final payloadStr = payload.encode();

    for (final member in members) {
      if (member.memberNodeId == localNodeId) {
        continue;
      }

      final packetId =
          'grp-ctrl-${payload.action}-${DateTime.now().microsecondsSinceEpoch}-${member.memberNodeId}';

      String wirePayload;
      if (_secureSessionService != null) {
        if (!_secureSessionService.hasSession(member.memberNodeId)) {
          continue;
        }
        try {
          final encrypted = await _secureSessionService.encrypt(
            peerNodeId: member.memberNodeId,
            plaintext: payloadStr,
            messageId: packetId,
            senderNodeId: localNodeId,
            recipientNodeId: member.memberNodeId,
          );
          wirePayload = encrypted.encode();
        } catch (_) {
          continue;
        }
      } else {
        wirePayload = payloadStr;
      }

      final packet = OfflinkPacket(
        messageId: packetId,
        senderNodeId: localNodeId,
        recipientNodeId: member.memberNodeId,
        messageType: OfflinkMessageType.groupMembership,
        timestamp: payload.timestamp,
        ttl: 4,
        payload: wirePayload,
      );

      try {
        await _packetTransport.sendPacket(
          peerId: member.memberNodeId,
          packet: packet,
        );
      } catch (_) {}
    }
  }

  Future<void> _handleIncomingPacket(OfflinkPacket packet) async {
    // 1. Process ACKs for group messages
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
        }
      }
      return;
    }

    // 2. Process Group Messages
    if (packet.messageType == OfflinkMessageType.groupMessage) {
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
          // Reject unauthenticated, replayed, or unencrypted packets safely
          return;
        }
      } else {
        decryptedString = packet.payload;
      }

      GroupMessagePayload groupPayload;
      try {
        groupPayload = GroupMessagePayload.decode(decryptedString);
      } catch (_) {
        return;
      }

      // Security Check: Envelope sender must match inner payload sender
      if (packet.senderNodeId != groupPayload.senderNodeId) {
        return;
      }

      // Security Check: Sender must be an authorized member if group exists locally
      final existingGroup = await _groupRepository.getGroup(
        groupPayload.groupId,
      );
      if (existingGroup != null) {
        final currentMembers = await _groupRepository.getGroupMembers(
          existingGroup.id,
        );
        final isSenderMember = currentMembers.any(
          (m) => m.memberNodeId == groupPayload.senderNodeId,
        );
        if (!isSenderMember) {
          // Sender is not in the group (or has been removed)
          return;
        }
      }

      final localNodeId =
          _identityManager.currentIdentity?.nodeId ?? 'local-node';

      // Reverse-path ACK back to sender
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

      // Deduplication check
      if (_messageRepository != null) {
        final existing = await _messageRepository.getMessageById(
          groupPayload.messageId,
        );
        if (existing != null) {
          return;
        }
      }

      // Ensure group exists locally
      var group = await _groupRepository.getGroup(groupPayload.groupId);
      if (group == null) {
        group = Group(
          id: groupPayload.groupId,
          name: groupPayload.groupName,
          creatorNodeId: groupPayload.senderNodeId,
          createdAt: groupPayload.timestamp,
          updatedAt: groupPayload.timestamp,
        );
        final members = [
          GroupMember(
            groupId: groupPayload.groupId,
            memberNodeId: groupPayload.senderNodeId,
            memberDisplayName: groupPayload.senderDisplayName,
            role: GroupMemberRole.member,
            joinedAt: groupPayload.timestamp,
          ),
          GroupMember(
            groupId: groupPayload.groupId,
            memberNodeId: localNodeId,
            memberDisplayName:
                _identityManager.currentIdentity?.username ?? 'Me',
            role: GroupMemberRole.member,
            joinedAt: groupPayload.timestamp,
          ),
        ];
        await _groupRepository.createGroup(group, members);
      }

      final chatMessage = ChatMessage(
        id: groupPayload.messageId,
        conversationId: 'group-${groupPayload.groupId}',
        senderNodeId: groupPayload.senderNodeId,
        recipientNodeId: groupPayload.groupId,
        content: groupPayload.content,
        timestamp: groupPayload.timestamp,
        isOutgoing: false,
        status: ChatMessageStatus.delivered,
      );

      final currentConv = await _conversationRepository?.getConversationById(
        'group-${groupPayload.groupId}',
      );
      final unread = (currentConv?.unreadCount ?? 0) + 1;
      await _conversationRepository?.upsertConversation(
        Conversation(
          id: 'group-${groupPayload.groupId}',
          peerNodeId: groupPayload.groupId,
          peerDisplayName: groupPayload.groupName,
          lastMessage: groupPayload.content,
          unreadCount: unread,
          updatedAt: groupPayload.timestamp,
        ),
      );

      await _messageRepository?.saveMessage(
        chatMessage,
        conversationId: 'group-${groupPayload.groupId}',
      );

      _incomingGroupMessagesController.add(chatMessage);
      return;
    }

    // 3. Process Group Membership Control Packets
    if (packet.messageType == OfflinkMessageType.groupMembership) {
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
          return;
        }
      } else {
        decryptedString = packet.payload;
      }

      GroupMembershipPayload membershipPayload;
      try {
        membershipPayload = GroupMembershipPayload.decode(decryptedString);
      } catch (_) {
        return;
      }

      // Security Check: Envelope sender must match adminNodeId for admin actions
      if (membershipPayload.action != 'leave' &&
          packet.senderNodeId != membershipPayload.adminNodeId) {
        return;
      }

      // Security Check: Verify sender has admin privileges if group exists
      if (membershipPayload.action == 'add' ||
          membershipPayload.action == 'remove') {
        final group = await _groupRepository.getGroup(
          membershipPayload.groupId,
        );
        if (group != null) {
          final members = await _groupRepository.getGroupMembers(group.id);
          final sender = members.where(
            (m) => m.memberNodeId == packet.senderNodeId,
          );
          if (sender.isEmpty || sender.first.role != GroupMemberRole.admin) {
            // Unauthorized membership modification attempt rejected
            return;
          }
        }
      }

      final localNodeId =
          _identityManager.currentIdentity?.nodeId ?? 'local-node';

      // Send ACK back
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

      if (membershipPayload.action == 'create' ||
          membershipPayload.action == 'join') {
        final existingGroup = await _groupRepository.getGroup(
          membershipPayload.groupId,
        );
        if (existingGroup == null) {
          final group = Group(
            id: membershipPayload.groupId,
            name: membershipPayload.groupName,
            creatorNodeId: membershipPayload.adminNodeId,
            createdAt: membershipPayload.timestamp,
            updatedAt: membershipPayload.timestamp,
          );
          await _groupRepository.createGroup(group, membershipPayload.members);
          await _conversationRepository?.upsertConversation(
            Conversation(
              id: 'group-${membershipPayload.groupId}',
              peerNodeId: membershipPayload.groupId,
              peerDisplayName: membershipPayload.groupName,
              lastMessage: 'Group joined',
              unreadCount: 0,
              updatedAt: membershipPayload.timestamp,
            ),
          );
          _groupEventsController.add(group);
        }
      } else if (membershipPayload.action == 'add') {
        for (final m in membershipPayload.members) {
          await _groupRepository.addMember(membershipPayload.groupId, m);
        }
      } else if (membershipPayload.action == 'remove') {
        if (membershipPayload.targetNodeId == localNodeId) {
          // Local user was removed from group
          await _groupRepository.removeMember(
            membershipPayload.groupId,
            localNodeId,
          );
        } else {
          await _groupRepository.removeMember(
            membershipPayload.groupId,
            membershipPayload.targetNodeId,
          );
        }
      }
      return;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _incomingGroupMessagesController.close();
    _groupEventsController.close();
  }
}
