import 'dart:async';

import 'package:flutter/material.dart';

import '../bluetooth/ble_discovery_event.dart';
import '../bluetooth/ble_models.dart';
import '../bluetooth/ble_packet_transport.dart';
import '../bluetooth/phone_ble_connection.dart';
import '../bluetooth/phone_ble_discovery.dart';
import '../domain/identity/identity_manager.dart';
import '../domain/protocol/offlink_message_type.dart';
import '../domain/protocol/offlink_packet.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.bleConnection,
    required this.packetTransport,
    this.identityManager,
  });

  final PhoneBleConnection bleConnection;
  final BlePacketTransport packetTransport;
  final IdentityManager? identityManager;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PhoneBleDiscovery _discovery;

  StreamSubscription<BleDiscoveryEvent>? _discoverySubscription;
  StreamSubscription<dynamic>? _connectionSubscription;
  StreamSubscription<dynamic>? _incomingPacketSubscription;

  final List<BlePeer> _nearbyPeers = [];
  final Set<String> _connectingPeerIds = {};
  final Set<String> _connectedPeerIds = {};

  OfflinkPacket? _lastReceivedPacket;

  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isStartingBle = false;
  bool _isDisposed = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _discovery = PhoneBleDiscovery();

    _discoverySubscription = _discovery.discoveryEvents.listen(
      _handleDiscoveryEvent,
    );

    _connectionSubscription = widget.bleConnection.connectionStates.listen((_) {
      if (!mounted || _isDisposed) {
        return;
      }

      setState(() {});
    });

    _incomingPacketSubscription = widget.packetTransport.incomingPackets.listen((
      packet,
    ) {
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

      debugPrint('[Offlink Packet] Initializing channel for: ${peer.peerId}');

      await widget.packetTransport.initializePeer(peer.peerId);

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
      await widget.packetTransport.sendPacket(
        peerId: peer.peerId,
        packet: packet,
      );

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
      await widget.packetTransport.sendPacket(
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
      _nearbyPeers.clear();
      _errorMessage = null;
    });

    await Future<void>.delayed(Duration.zero);
  }

  @override
  void dispose() {
    _isDisposed = true;

    _discoverySubscription?.cancel();
    _connectionSubscription?.cancel();
    _incomingPacketSubscription?.cancel();

    _discovery.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offlink'),
        actions: [
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
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _replyToLastPacket,
                icon: const Icon(Icons.reply, size: 18),
                label: const Text('Reply with Pong'),
              ),
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

  Widget _buildNearbySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nearby Offlink Users',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (_nearbyPeers.isEmpty)
          _buildEmptyNearbyState()
        else
          ..._nearbyPeers.map(_buildPeerTile),
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
