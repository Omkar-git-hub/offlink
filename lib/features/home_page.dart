import 'dart:async';

import 'package:flutter/material.dart';

import '../bluetooth/adaptive_ble_discovery.dart';
import '../bluetooth/ble_discovery_event.dart';
import '../bluetooth/ble_models.dart';
import '../bluetooth/ble_packet_transport.dart';
import '../bluetooth/discovery.dart';
import '../bluetooth/phone_ble_connection.dart';
import '../bluetooth/phone_ble_discovery.dart';
import '../domain/battery/adaptive_power_coordinator.dart';
import '../domain/group/group.dart';
import '../domain/group/group_member.dart';
import '../domain/group/group_message_service.dart';
import '../domain/group/group_repository.dart';
import '../domain/identity/identity_manager.dart';
import '../domain/lifecycle/app_lifecycle_coordinator.dart';
import '../domain/lifecycle/connection_recovery_coordinator.dart';
import '../domain/mesh/mesh_packet_router.dart';
import '../domain/messaging/message_repository.dart';
import '../domain/messaging/message_service.dart';
import '../domain/location/location_service.dart';
import '../domain/protocol/offlink_message_type.dart';
import '../domain/protocol/offlink_packet.dart';
import '../domain/security/peer_security_repository.dart';
import '../domain/security/trust_status.dart';
import 'chat/chat_page.dart';
import 'chat/group_chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.bleConnection,
    required this.packetTransport,
    this.meshRouter,
    this.discovery,
    this.lifecycleCoordinator,
    this.connectionRecovery,
    this.powerCoordinator,
    this.identityManager,
    this.messageService,
    this.messageRepository,
    this.groupMessageService,
    this.groupRepository,
    this.locationService,
    this.securityRepository,
  });

  final PhoneBleConnection bleConnection;
  final BlePacketTransport packetTransport;
  final MeshPacketRouter? meshRouter;
  final BleDiscovery? discovery;
  final AppLifecycleCoordinator? lifecycleCoordinator;
  final ConnectionRecoveryCoordinator? connectionRecovery;
  final AdaptivePowerCoordinator? powerCoordinator;
  final IdentityManager? identityManager;
  final MessageService? messageService;
  final MessageRepository? messageRepository;
  final GroupMessageService? groupMessageService;
  final GroupRepository? groupRepository;
  final LocationService? locationService;
  final PeerSecurityRepository? securityRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final BleDiscovery _discovery;

  StreamSubscription<BleDiscoveryEvent>? _discoverySubscription;
  StreamSubscription<dynamic>? _connectionSubscription;
  StreamSubscription<dynamic>? _incomingPacketSubscription;
  StreamSubscription<List<BlockedPeer>>? _blockedPeersSubscription;

  final List<BlePeer> _nearbyPeers = [];
  final Set<String> _connectingPeerIds = {};
  final Set<String> _connectedPeerIds = {};
  final Set<String> _blockedPeerIds = {};

  OfflinkPacket? _lastReceivedPacket;

  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isStartingBle = false;
  bool _isDisposed = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    widget.lifecycleCoordinator?.initialize();

    _blockedPeersSubscription = widget.securityRepository
        ?.watchBlockedPeers()
        .listen((blocked) {
          if (!mounted || _isDisposed) return;
          setState(() {
            _blockedPeerIds.clear();
            _blockedPeerIds.addAll(blocked.map((p) => p.nodeId));
          });
        });

    _discovery = widget.discovery ?? PhoneBleDiscovery();

    _discoverySubscription = _discovery.discoveryEvents.listen(
      _handleDiscoveryEvent,
    );

    _connectionSubscription = widget.bleConnection.connectionStates.listen((_) {
      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {});
    });

    final packetStream = widget.meshRouter != null
        ? widget.meshRouter!.incomingPackets
        : widget.packetTransport.incomingPackets;

    _incomingPacketSubscription = packetStream.listen((packet) {
      debugPrint(
        '[Offlink Packet] Received: ${packet.messageId} from ${packet.senderNodeId}',
      );

      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _lastReceivedPacket = packet;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Received packet from ${packet.senderNodeId.length > 8 ? packet.senderNodeId.substring(0, 8) : packet.senderNodeId}: "${packet.payload}"',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });

    _startBle();
  }

  Future<void> _startBle() async {
    if (_isDisposed || _isStartingBle) {
      return;
    }

    _isStartingBle = true;

    if (mounted) {
      setState(() {
        _errorMessage = null;
      });
    }

    try {
      await _discovery.startAdvertising();

      if (_isDisposed) {
        return;
      }

      if (mounted) {
        setState(() {
          _isAdvertising = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isAdvertising = false;
          _errorMessage = 'Unable to start BLE advertising: $error';
        });
      }
    }

    try {
      await _discovery.startScanning();

      if (_isDisposed) {
        return;
      }

      if (mounted) {
        setState(() {
          _isScanning = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Unable to start BLE scanning: $error';
        });
      }
    } finally {
      _isStartingBle = false;
    }
  }

  void _handleDiscoveryEvent(BleDiscoveryEvent event) {
    if (!mounted || _isDisposed) {
      return;
    }

    setState(() {
      if (event.type == BleDiscoveryEventType.discovered) {
        final existingIndex = _nearbyPeers.indexWhere(
          (peer) => peer.peerId == event.peer.peerId,
        );

        if (existingIndex == -1) {
          _nearbyPeers.add(event.peer);
        } else {
          _nearbyPeers[existingIndex] = event.peer;
        }
      } else if (event.type == BleDiscoveryEventType.lost) {
        _nearbyPeers.removeWhere((peer) => peer.peerId == event.peer.peerId);

        _connectingPeerIds.remove(event.peer.peerId);
        _connectedPeerIds.remove(event.peer.peerId);
      }
    });
  }

  Future<void> _connectToPeer(BlePeer peer) async {
    if (_isDisposed ||
        _connectingPeerIds.contains(peer.peerId) ||
        _connectedPeerIds.contains(peer.peerId)) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _connectingPeerIds.add(peer.peerId);
    });

    try {
      debugPrint('[Offlink BLE] Connecting to peer: ${peer.peerId}');

      await widget.bleConnection.connect(peer);
      widget.connectionRecovery?.onPeerConnected(peer.peerId);
      widget.connectionRecovery?.trackPeer(peer);

      debugPrint('[Offlink Packet] Initializing channel for: ${peer.peerId}');

      await widget.packetTransport.initializePeer(peer.peerId);
      widget.meshRouter?.addDirectNeighbor(peer.peerId);
      widget.lifecycleCoordinator?.pendingMessageRecovery
          .onPeerOrRouteAvailable(peer.peerId);

      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _connectingPeerIds.remove(peer.peerId);
        _connectedPeerIds.add(peer.peerId);
      });

      debugPrint('[Offlink BLE] Connected to peer: ${peer.peerId}');
      debugPrint('[Offlink Packet] Packet channel ready: ${peer.peerId}');
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }

      try {
        await widget.bleConnection.disconnect(peer.peerId);
      } catch (_) {
        // Ignore cleanup failure.
      }

      setState(() {
        _connectingPeerIds.remove(peer.peerId);
        _connectedPeerIds.remove(peer.peerId);
        _errorMessage = 'Unable to connect to ${peer.displayName}: $error';
      });

      debugPrint('[Offlink BLE] Connection failed for ${peer.peerId}: $error');
    }
  }

  Future<void> _disconnectFromPeer(BlePeer peer) async {
    if (_isDisposed || !_connectedPeerIds.contains(peer.peerId)) {
      return;
    }

    try {
      debugPrint('[Offlink BLE] Disconnecting from peer: ${peer.peerId}');

      widget.connectionRecovery?.untrackPeer(peer.peerId);
      widget.meshRouter?.removePeer(peer.peerId);
      await widget.packetTransport.removePeer(peer.peerId);

      await widget.bleConnection.disconnect(peer.peerId);

      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _connectedPeerIds.remove(peer.peerId);
      });

      debugPrint('[Offlink BLE] Disconnected from peer: ${peer.peerId}');
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to disconnect from ${peer.displayName}: $error';
      });
    }
  }

  void _openChat(BlePeer peer) {
    final messageService = widget.messageService;
    if (messageService == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          peer: peer,
          messageService: messageService,
          messageRepository: widget.messageRepository,
          locationService: widget.locationService,
          securityRepository: widget.securityRepository,
          isConnected: _connectedPeerIds.contains(peer.peerId),
        ),
      ),
    );
  }

  void _openGroupChat(Group group) {
    if (widget.groupMessageService == null || widget.groupRepository == null) {
      return;
    }

    final localNodeId =
        widget.identityManager?.currentIdentity?.nodeId ?? 'local-node';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupChatPage(
          group: group,
          groupMessageService: widget.groupMessageService!,
          groupRepository: widget.groupRepository!,
          messageRepository: widget.messageRepository,
          locationService: widget.locationService,
          localNodeId: localNodeId,
        ),
      ),
    );
  }

  Future<void> _promptCreateGroup() async {
    final nameCtrl = TextEditingController();
    final selectedPeerIds = <String>{};

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'e.g. Field Team',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Members:'),
                  const SizedBox(height: 8),
                  if (_nearbyPeers.isEmpty)
                    const Text(
                      'No nearby peers discovered yet.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ..._nearbyPeers.map((peer) {
                      final isSelected = selectedPeerIds.contains(peer.peerId);
                      return CheckboxListTile(
                        value: isSelected,
                        dense: true,
                        title: Text(peer.displayName),
                        subtitle: Text(peer.peerId),
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedPeerIds.add(peer.peerId);
                            } else {
                              selectedPeerIds.remove(peer.peerId);
                            }
                          });
                        },
                      );
                    }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      final initialMembers = selectedPeerIds.map((peerId) {
        final peer = _nearbyPeers.firstWhere((p) => p.peerId == peerId);
        return GroupMember(
          groupId: '',
          memberNodeId: peer.peerId,
          memberDisplayName: peer.displayName,
          role: GroupMemberRole.member,
          joinedAt: DateTime.now().toUtc(),
        );
      }).toList();

      final newGroup = await widget.groupMessageService!.createGroup(
        name: nameCtrl.text.trim(),
        initialMembers: initialMembers,
      );

      if (mounted) {
        _openGroupChat(newGroup);
      }
    }
  }

  Future<void> _sendTestPacket(BlePeer peer) async {
    final identity = widget.identityManager?.currentIdentity;
    final senderNodeId = identity?.nodeId ?? 'node-local';
    final username = identity?.username ?? 'Offlink User';

    final packet = OfflinkPacket(
      messageId: 'ping-${DateTime.now().millisecondsSinceEpoch}',
      senderNodeId: senderNodeId,
      recipientNodeId: peer.peerId,
      messageType: OfflinkMessageType.text,
      timestamp: DateTime.now().toUtc(),
      ttl: 3,
      payload: 'Ping from $username',
    );

    try {
      final transport = widget.meshRouter ?? widget.packetTransport;
      await transport.sendPacket(peerId: peer.peerId, packet: packet);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Packet sent to ${peer.displayName}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send packet: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _replyToLastPacket() async {
    final lastPacket = _lastReceivedPacket;
    if (lastPacket == null) {
      return;
    }

    final identity = widget.identityManager?.currentIdentity;
    final senderNodeId = identity?.nodeId ?? 'node-local';
    final username = identity?.username ?? 'Offlink User';

    final replyPacket = OfflinkPacket(
      messageId: 'pong-${DateTime.now().millisecondsSinceEpoch}',
      senderNodeId: senderNodeId,
      recipientNodeId: lastPacket.senderNodeId,
      messageType: OfflinkMessageType.text,
      timestamp: DateTime.now().toUtc(),
      ttl: 3,
      payload: 'Pong reply from $username',
    );

    try {
      final transport = widget.meshRouter ?? widget.packetTransport;
      await transport.sendPacket(
        peerId: lastPacket.senderNodeId,
        packet: replyPacket,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reply sent to ${lastPacket.senderNodeId.length > 8 ? lastPacket.senderNodeId.substring(0, 8) : lastPacket.senderNodeId}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reply: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _refreshNearbyPeers() async {
    if (_isDisposed) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final discovery = _discovery;
    if (discovery is AdaptiveBleDiscovery) {
      await discovery.triggerImmediateScan();
    } else {
      await discovery.completeScanCycle();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _discoverySubscription?.cancel();
    _connectionSubscription?.cancel();
    _incomingPacketSubscription?.cancel();
    _blockedPeersSubscription?.cancel();

    if (widget.discovery == null) {
      final discovery = _discovery;
      if (discovery is PhoneBleDiscovery) {
        discovery.dispose();
      } else if (discovery is AdaptiveBleDiscovery) {
        discovery.dispose();
      }
    }

    super.dispose();
  }

  Future<void> _showBlockedPeersSheet() async {
    final repo = widget.securityRepository;
    if (repo == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StreamBuilder<List<BlockedPeer>>(
          stream: repo.watchBlockedPeers(),
          builder: (context, snapshot) {
            final blockedList = snapshot.data ?? [];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.block, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Blocked Peers',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    if (blockedList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No blocked peers')),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: blockedList.length,
                          itemBuilder: (context, index) {
                            final peer = blockedList[index];
                            final shortId = peer.nodeId.length > 12
                                ? '${peer.nodeId.substring(0, 12)}...'
                                : peer.nodeId;
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_off),
                              ),
                              title: Text(shortId),
                              subtitle: Text(peer.reason),
                              trailing: TextButton(
                                onPressed: () async {
                                  await repo.unblockPeer(peer.nodeId);
                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text('Unblocked $shortId'),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Unblock'),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offlink'),
        actions: [
          if (widget.securityRepository != null)
            IconButton(
              tooltip: 'Blocked Peers',
              onPressed: _showBlockedPeersSheet,
              icon: const Icon(Icons.block),
            ),
          IconButton(
            tooltip: 'Refresh nearby users',
            onPressed: _refreshNearbyPeers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshNearbyPeers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildBleStatusCard(),
            if (_lastReceivedPacket != null) ...[
              const SizedBox(height: 16),
              _buildLastReceivedPacketCard(),
            ],
            if (widget.groupRepository != null &&
                widget.groupMessageService != null) ...[
              const SizedBox(height: 20),
              _buildGroupsSection(),
            ],
            const SizedBox(height: 20),
            _buildNearbySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBleStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Offlink BLE',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              icon: Icons.bluetooth_searching,
              label: 'Scanning',
              enabled: _isScanning,
            ),
            const SizedBox(height: 10),
            _buildStatusRow(
              icon: Icons.bluetooth_connected,
              label: 'Advertising',
              enabled: _isAdvertising,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLastReceivedPacketCard() {
    final packet = _lastReceivedPacket!;
    final senderLabel = packet.senderNodeId.length > 12
        ? '${packet.senderNodeId.substring(0, 12)}...'
        : packet.senderNodeId;

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mark_email_read,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Last Received Packet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('From: $senderLabel'),
            Text('Type: ${packet.messageType.value} (TTL: ${packet.ttl})'),
            const SizedBox(height: 4),
            Text(
              'Payload: "${packet.payload}"',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.messageService != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openChat(
                      BlePeer(
                        peerId: packet.senderNodeId,
                        displayName: 'Sender $senderLabel',
                      ),
                    ),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Open Chat'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonalIcon(
                  onPressed: _replyToLastPacket,
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Reply with Pong'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: enabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Icon(
          enabled ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: enabled ? Colors.green : Theme.of(context).colorScheme.outline,
        ),
      ],
    );
  }

  Widget _buildGroupsSection() {
    return StreamBuilder<List<Group>>(
      stream: widget.groupRepository!.watchAllGroups(),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Groups (${groups.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.tonalIcon(
                  onPressed: _promptCreateGroup,
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text('New Group'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No groups created yet.',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create a group to chat with multiple nearby peers simultaneously.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...groups.map((group) {
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.groups)),
                    title: Text(group.name),
                    subtitle: Text('ID: ${group.id}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openGroupChat(group),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildNearbySection() {
    final visiblePeers = _nearbyPeers
        .where((peer) => !_blockedPeerIds.contains(peer.peerId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nearby Offlink Users',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (visiblePeers.isEmpty)
          _buildEmptyNearbyState()
        else
          ...visiblePeers.map(_buildPeerTile),
      ],
    );
  }

  Widget _buildEmptyNearbyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'No nearby Offlink users found.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Keep Bluetooth enabled and bring another Offlink device nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerTile(BlePeer peer) {
    final isConnecting = _connectingPeerIds.contains(peer.peerId);
    final isConnected = _connectedPeerIds.contains(peer.peerId);

    return Card(
      child: ListTile(
        onTap: isConnected && widget.messageService != null
            ? () => _openChat(peer)
            : null,
        leading: CircleAvatar(
          child: Icon(isConnected ? Icons.bluetooth_connected : Icons.person),
        ),
        title: Text(
          peer.displayName.isNotEmpty
              ? peer.displayName
              : 'Unknown Offlink User',
        ),
        subtitle: Text(
          isConnected ? 'Connected' : 'Signal: ${peer.signalStrength} dBm',
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isConnected
            ? Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.messageService != null)
                    FilledButton.icon(
                      onPressed: () => _openChat(peer),
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('Chat'),
                    ),
                  FilledButton.tonal(
                    onPressed: () => _sendTestPacket(peer),
                    child: const Text('Send Ping'),
                  ),
                  TextButton(
                    onPressed: () => _disconnectFromPeer(peer),
                    child: const Text('Disconnect'),
                  ),
                ],
              )
            : FilledButton(
                onPressed: () => _connectToPeer(peer),
                child: const Text('Connect'),
              ),
      ),
    );
  }
}
