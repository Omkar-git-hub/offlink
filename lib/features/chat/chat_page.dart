import 'dart:async';

import 'package:flutter/material.dart';

import '../../bluetooth/ble_models.dart';
import '../../domain/location/live_location_session.dart';
import '../../domain/location/location_payload.dart';
import '../../domain/location/location_service.dart';
import '../../domain/messaging/chat_message.dart';
import '../../domain/messaging/direct_message_service.dart';
import '../../domain/messaging/message_repository.dart';
import '../../domain/messaging/message_service.dart';
import '../location/location_bubble.dart';
import '../location/location_sharing_sheet.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.peer,
    required this.messageService,
    this.messageRepository,
    this.locationService,
    this.isConnected = true,
  });

  final BlePeer peer;
  final MessageService messageService;
  final MessageRepository? messageRepository;
  final LocationService? locationService;
  final bool isConnected;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<ChatMessage>? _locationSubscription;
  StreamSubscription<List<LiveLocationSession>>? _activeSessionsSubscription;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    _messageSubscription = widget.messageService.incomingMessages.listen(
      _handleIncomingMessage,
    );

    if (widget.locationService != null) {
      _locationSubscription = widget.locationService!.locationMessages.listen(
        _handleLocationMessage,
      );
      _activeSessionsSubscription = widget.locationService!.activeSessionsStream
          .listen((_) {
            if (mounted) setState(() {});
          });
    }

    if (widget.messageRepository != null) {
      _loadPersistedHistory();
    }

    if (widget.messageService is DirectMessageService && widget.isConnected) {
      final directService = widget.messageService as DirectMessageService;
      if (!directService.hasSecureSession(widget.peer.peerId)) {
        directService.initiateSecureSession(
          peerId: widget.peer.peerId,
          recipientNodeId: widget.peer.peerId,
        );
      }
    }
  }

  Future<void> _loadPersistedHistory() async {
    try {
      final history = await widget.messageRepository!
          .getMessagesForConversation(widget.peer.peerId);
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
    } catch (_) {
      // Gracefully handle persistence retrieval errors
    }
  }

  void _handleIncomingMessage(ChatMessage message) {
    if (message.senderNodeId == widget.peer.peerId ||
        message.recipientNodeId == widget.peer.peerId) {
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
      });
      _scrollToBottom();
    }
  }

  void _handleLocationMessage(ChatMessage message) {
    if (message.conversationId == widget.peer.peerId ||
        message.senderNodeId == widget.peer.peerId ||
        message.recipientNodeId == widget.peer.peerId) {
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
    if (_isSending) {
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    _textController.clear();

    try {
      final message = await widget.messageService.sendMessage(
        peerId: widget.peer.peerId,
        recipientNodeId: widget.peer.peerId,
        content: text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEncrypted =
        widget.messageService is DirectMessageService &&
        (widget.messageService as DirectMessageService).hasSecureSession(
          widget.peer.peerId,
        );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peer.displayName.isNotEmpty
                  ? widget.peer.displayName
                  : 'Offlink User',
              style: const TextStyle(fontSize: 18),
            ),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: widget.isConnected ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isConnected ? 'Connected' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isEncrypted) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Encrypted',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.locationService?.isLiveLocationActive(
                  widget.peer.peerId,
                ) ==
                true)
              _buildLiveSharingBanner(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to start communicating offline over BLE.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSharingBanner() {
    final session = widget.locationService?.getActiveLiveSession(
      widget.peer.peerId,
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
              'Sharing live location (~$remainingMinutes min remaining)',
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
              widget.locationService?.stopLiveLocation(widget.peer.peerId);
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

  Widget _buildMessageBubble(ChatMessage message) {
    if (LocationPayload.isLocationMessage(message.content)) {
      try {
        final payload = LocationPayload.decode(message.content);
        return LocationBubble(message: message, payload: payload);
      } catch (_) {}
    }

    final theme = Theme.of(context);
    final isOutgoing = message.isOutgoing;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOutgoing
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
            bottomRight: Radius.circular(isOutgoing ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isOutgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 15,
                color: isOutgoing
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        (isOutgoing
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurfaceVariant)
                            .withValues(alpha: 0.7),
                  ),
                ),
                if (isOutgoing) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == ChatMessageStatus.sent ||
                            message.status == ChatMessageStatus.delivered
                        ? Icons.check
                        : Icons.access_time,
                    size: 13,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.locationService != null) ...[
            IconButton(
              icon: const Icon(Icons.location_on_outlined),
              tooltip: 'Share Location',
              color: theme.colorScheme.primary,
              onPressed: () {
                LocationSharingSheet.show(
                  context: context,
                  locationService: widget.locationService!,
                  targetId: widget.peer.peerId,
                  targetName: widget.peer.displayName,
                  isGroup: false,
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type an offline message...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send message',
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
