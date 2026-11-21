import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/group/group.dart';
import '../../domain/group/group_member.dart';
import '../../domain/group/group_message_service.dart';
import '../../domain/group/group_repository.dart';
import '../../domain/location/live_location_session.dart';
import '../../domain/location/location_payload.dart';
import '../../domain/location/location_service.dart';
import '../../domain/messaging/chat_message.dart';
import '../../domain/messaging/message_repository.dart';
import '../location/location_bubble.dart';
import '../location/location_sharing_sheet.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({
    super.key,
    required this.group,
    required this.groupMessageService,
    required this.groupRepository,
    this.messageRepository,
    this.locationService,
    required this.localNodeId,
  });

  final Group group;
  final GroupMessageService groupMessageService;
  final GroupRepository groupRepository;
  final MessageRepository? messageRepository;
  final LocationService? locationService;
  final String localNodeId;

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<ChatMessage>? _locationSubscription;
  StreamSubscription<List<LiveLocationSession>>? _activeSessionsSubscription;
  List<GroupMember> _members = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    _messageSubscription = widget.groupMessageService.incomingGroupMessages
        .listen(_handleIncomingMessage);

    if (widget.locationService != null) {
      _locationSubscription = widget.locationService!.locationMessages.listen(
        _handleLocationMessage,
      );
      _activeSessionsSubscription = widget.locationService!.activeSessionsStream
          .listen((_) {
            if (mounted) setState(() {});
          });
    }

    _loadMembers();
    widget.groupMessageService.initiateSecureSessionsForGroup(widget.group.id);
    if (widget.messageRepository != null) {
      _loadPersistedHistory();
    }
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.groupRepository.getGroupMembers(
        widget.group.id,
      );
      if (mounted) {
        setState(() {
          _members = members;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPersistedHistory() async {
    try {
      final history = await widget.messageRepository!
          .getMessagesForConversation('group-${widget.group.id}');
      if (!mounted) return;
      setState(() {
        for (final msg in history) {
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
          }
        }
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  void _handleIncomingMessage(ChatMessage message) {
    if (message.conversationId == 'group-${widget.group.id}') {
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
      });
      _scrollToBottom();
    }
  }

  void _handleLocationMessage(ChatMessage message) {
    if (message.conversationId == 'group-${widget.group.id}' ||
        message.recipientNodeId == widget.group.id) {
      setState(() {
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);
        if (existingIndex >= 0) {
          _messages[existingIndex] = message;
        } else {
          _messages.add(message);
        }
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final sentMessage = await widget.groupMessageService.sendGroupMessage(
        groupId: widget.group.id,
        content: text,
      );

      _textController.clear();
      setState(() {
        if (!_messages.any((m) => m.id == sentMessage.id)) {
          _messages.add(sentMessage);
        }
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send group message: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showGroupDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAdmin = _members.any(
              (m) =>
                  m.memberNodeId == widget.localNodeId &&
                  m.role == GroupMemberRole.admin,
            );

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Text(
                        widget.group.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Group ID: ${widget.group.id}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Members (${_members.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isAdmin)
                            FilledButton.tonalIcon(
                              onPressed: () => _promptAddMember(setModalState),
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('Add Member'),
                            ),
                        ],
                      ),
                      const Divider(),
                      ..._members.map((member) {
                        final isMemberAdmin =
                            member.role == GroupMemberRole.admin;
                        final isSelf =
                            member.memberNodeId == widget.localNodeId;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.memberDisplayName.isNotEmpty
                                  ? member.memberDisplayName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(
                            isSelf
                                ? '${member.memberDisplayName} (You)'
                                : member.memberDisplayName,
                          ),
                          subtitle: Text(
                            member.memberNodeId.length > 12
                                ? '${member.memberNodeId.substring(0, 12)}...'
                                : member.memberNodeId,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  isMemberAdmin ? 'Admin' : 'Member',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (isAdmin && !isSelf) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeMember(
                                    member.memberNodeId,
                                    setModalState,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _promptAddMember(StateSetter setModalState) async {
    final nodeIdCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Group Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nodeIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Member Node ID',
                hintText: 'e.g. node-xyz',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'e.g. Bob',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nodeIdCtrl.text.trim().isNotEmpty) {
      final nodeId = nodeIdCtrl.text.trim();
      final displayName = nameCtrl.text.trim().isEmpty
          ? nodeId
          : nameCtrl.text.trim();

      await widget.groupMessageService.addMember(
        groupId: widget.group.id,
        memberNodeId: nodeId,
        memberDisplayName: displayName,
      );

      await _loadMembers();
      setModalState(() {});
    }
  }

  Future<void> _removeMember(
    String memberNodeId,
    StateSetter setModalState,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text(
          'Are you sure you want to remove this member from the group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.groupMessageService.removeMember(
        groupId: widget.group.id,
        memberNodeId: memberNodeId,
      );
      await _loadMembers();
      setModalState(() {});
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _locationSubscription?.cancel();
    _activeSessionsSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildLiveSharingBanner() {
    final session = widget.locationService?.getActiveLiveSession(
      widget.group.id,
    );
    final remainingMinutes = session?.remainingTime().inMinutes ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.withValues(alpha: 0.15),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sharing live location with group (~$remainingMinutes min remaining)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              widget.locationService?.stopLiveLocation(widget.group.id);
            },
            child: const Text(
              'Stop',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showGroupDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.group.name, style: const TextStyle(fontSize: 18)),
              Text(
                '${_members.length} members',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Group Details',
            onPressed: _showGroupDetails,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.locationService?.isLiveLocationActive(widget.group.id) ==
              true)
            _buildLiveSharingBanner(),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet in ${widget.group.name}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (LocationPayload.isLocationMessage(message.content)) {
      try {
        final payload = LocationPayload.decode(message.content);
        return LocationBubble(message: message, payload: payload);
      } catch (_) {}
    }

    final isOutgoing = message.isOutgoing;
    final colorScheme = Theme.of(context).colorScheme;

    String? senderName;
    if (!isOutgoing) {
      final senderMember = _members.firstWhere(
        (m) => m.memberNodeId == message.senderNodeId,
        orElse: () => GroupMember(
          groupId: widget.group.id,
          memberNodeId: message.senderNodeId,
          memberDisplayName: message.senderNodeId.length > 8
              ? '${message.senderNodeId.substring(0, 8)}...'
              : message.senderNodeId,
          joinedAt: DateTime.now(),
        ),
      );
      senderName = senderMember.memberDisplayName;
    }

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOutgoing
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isOutgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isOutgoing && senderName != null) ...[
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                color: isOutgoing
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: colorScheme.outline),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  _buildDeliveryStatusIcon(message),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryStatusIcon(ChatMessage message) {
    final statuses = widget.groupMessageService.getMemberDeliveryStatuses(
      message.id,
    );
    final isFullyDelivered =
        statuses.isNotEmpty &&
        statuses.values.every((s) => s == ChatMessageStatus.delivered);

    if (isFullyDelivered || message.status == ChatMessageStatus.delivered) {
      return const Icon(Icons.done_all, size: 14, color: Colors.blue);
    }
    return const Icon(Icons.done, size: 14, color: Colors.grey);
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (widget.locationService != null) ...[
              IconButton(
                icon: const Icon(Icons.location_on_outlined),
                tooltip: 'Share Location',
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  LocationSharingSheet.show(
                    context: context,
                    locationService: widget.locationService!,
                    targetId: widget.group.id,
                    targetName: widget.group.name,
                    isGroup: true,
                    memberCount: _members.length,
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _isSending ? null : _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
