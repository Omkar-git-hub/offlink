import 'dart:async';

import 'package:flutter/material.dart';

import '../bluetooth/ble_discovery_event.dart';
import '../bluetooth/ble_models.dart';
import '../bluetooth/phone_ble_discovery.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PhoneBleDiscovery _discovery;

  StreamSubscription<BleDiscoveryEvent>? _discoverySubscription;

  final List<BlePeer> _nearbyPeers = [];

  bool _isScanning = false;
  bool _isAdvertising = false;
  bool _isStartingBle = false;
  bool _isDisposed = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _discovery = PhoneBleDiscovery();

    _discoverySubscription =
        _discovery.discoveryEvents.listen(_handleDiscoveryEvent);

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
        _nearbyPeers.removeWhere(
          (peer) => peer.peerId == event.peer.peerId,
        );
      }
    });
  }

  Future<void> _refreshNearbyPeers() async {
    if (_isDisposed) {
      return;
    }

    setState(() {
      _nearbyPeers.clear();
      _errorMessage = null;
    });

    /*
     * Do not stop and restart BLE here.
     *
     * BLE scanning and advertising are long-lived operations for the
     * current HomePage session. Restarting them repeatedly can cause
     * Android to reject scan registration because of excessive scan
     * frequency.
     *
     * The refresh action only refreshes the UI state.
     */
    await Future<void>.delayed(Duration.zero);
  }

  @override
  void dispose() {
    _isDisposed = true;

    _discoverySubscription?.cancel();
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Icon(
          enabled ? Icons.check_circle : Icons.cancel,
          size: 20,
          color: enabled
              ? Colors.green
              : Theme.of(context).colorScheme.outline,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerTile(BlePeer peer) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person),
        ),
        title: Text(
          peer.displayName.isNotEmpty
              ? peer.displayName
              : 'Unknown Offlink User',
        ),
        subtitle: Text(
          'Signal: ${peer.signalStrength} dBm',
        ),
        trailing: const Icon(Icons.bluetooth),
      ),
    );
  }
}