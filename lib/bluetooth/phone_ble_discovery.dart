import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_advertiser.dart';
import 'ble_discovery_event.dart';
import 'ble_models.dart';
import 'ble_peer_tracker.dart';
import 'ble_scan_data.dart';
import 'ble_scan_result_mapper.dart';
import 'ble_scanner.dart';
import 'ble_service_filter.dart';
import 'discovery.dart';
import 'offlink_ble_service.dart';

class PhoneBleDiscovery implements BleDiscovery {
  PhoneBleDiscovery({
    BleServiceFilter? serviceFilter,
    BleScanResultMapper? scanResultMapper,
    BleScanner? scanner,
    BleAdvertiser? advertiser,
    BlePeerTracker? peerTracker,
  }) : _serviceFilter = serviceFilter ?? const BleServiceFilter(),
       _scanResultMapper =
           scanResultMapper ??
           BleScanResultMapper(
             serviceFilter: serviceFilter ?? const BleServiceFilter(),
           ),
       _scanner = scanner ?? const FlutterBluePlusScanner(),
       _advertiser = advertiser ?? const FlutterBleAdvertiser(),
       _peerTracker = peerTracker ?? BlePeerTracker();

  final BleServiceFilter _serviceFilter;
  final BleScanResultMapper _scanResultMapper;
  final BleScanner _scanner;
  final BleAdvertiser _advertiser;
  final BlePeerTracker _peerTracker;

  final StreamController<BlePeer> _discoveredPeersController =
      StreamController<BlePeer>.broadcast();

  final StreamController<BleDiscoveryEvent> _discoveryEventsController =
      StreamController<BleDiscoveryEvent>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final Set<String> _currentScanPeerIds = {};

  bool _isScanning = false;
  bool _isAdvertising = false;

  @override
  Future<void> startScanning() async {
    if (_isScanning) {
      return;
    }

    _currentScanPeerIds.clear();
    _isScanning = true;

    _scanSubscription = _scanner.scanResults.listen(_handleScanResults);

    try {
      await _scanner.startScan(
        withServices: [Guid(OfflinkBleService.serviceUuid)],
      );
    } catch (_) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      _currentScanPeerIds.clear();
      rethrow;
    }
  }

  @override
  Future<void> stopScanning() async {
    if (!_isScanning) {
      return;
    }

    await _scanner.stopScan();
    await _scanSubscription?.cancel();

    _scanSubscription = null;
    _isScanning = false;
  }

  @override
  Future<Set<String>> completeScanCycle() async {
    final lostPeers = _peerTracker.retainOnlyPeers(_currentScanPeerIds);

    _currentScanPeerIds.clear();

    for (final peer in lostPeers) {
      _discoveryEventsController.add(
        BleDiscoveryEvent(type: BleDiscoveryEventType.lost, peer: peer),
      );
    }

    return lostPeers.map((peer) => peer.peerId).toSet();
  }

  @override
  Future<void> startAdvertising() async {
    if (_isAdvertising) {
      return;
    }

    await _advertiser.start();

    _isAdvertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) {
      return;
    }

    await _advertiser.stop();

    _isAdvertising = false;
  }

  @override
  Stream<BlePeer> get discoveredPeers => _discoveredPeersController.stream;

  @override
  Stream<BleDiscoveryEvent> get discoveryEvents =>
      _discoveryEventsController.stream;

  bool isOfflinkService(String serviceUuid) {
    return _serviceFilter.isOfflinkService(serviceUuid);
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      String? advertisedUsername;
      final mfgData = result
          .advertisementData
          .manufacturerData[OfflinkBleService.manufacturerId];
      if (mfgData != null && mfgData.isNotEmpty) {
        try {
          final decoded = utf8.decode(mfgData).trim();
          if (decoded.isNotEmpty) {
            advertisedUsername = decoded;
          }
        } catch (_) {}
      }

      final hardwareModel = result.device.platformName.trim().isNotEmpty
          ? result.device.platformName.trim()
          : null;

      final advName = result.advertisementData.advName.trim();

      // Determine display name hierarchy:
      // 1. Advertised Offlink username (from manufacturerData in scan response)
      // 2. Non-generic advName (if set and not matching platformName)
      // 3. Fallback to clean 'Offlink User'
      final String effectiveDisplayName;
      final String? effectiveUsername;

      if (advertisedUsername != null && advertisedUsername.isNotEmpty) {
        effectiveDisplayName = advertisedUsername;
        effectiveUsername = advertisedUsername;
      } else if (advName.isNotEmpty &&
          (hardwareModel == null ||
              advName.toLowerCase() != hardwareModel.toLowerCase())) {
        effectiveDisplayName = advName;
        effectiveUsername = advName;
      } else {
        effectiveDisplayName = 'Offlink User';
        effectiveUsername = null;
      }

      final scanData = BleScanData(
        peerId: result.device.remoteId.str,
        displayName: effectiveDisplayName,
        deviceModel: hardwareModel,
        username: effectiveUsername,
        signalStrength: result.rssi,
        serviceUuids: result.advertisementData.serviceUuids
            .map((uuid) => uuid.str)
            .toList(),
      );

      final peer = _scanResultMapper.map(scanData);

      if (peer == null) {
        continue;
      }

      _currentScanPeerIds.add(peer.peerId);

      final isNewPeer = _peerTracker.add(peer);

      if (isNewPeer) {
        _discoveredPeersController.add(peer);

        _discoveryEventsController.add(
          BleDiscoveryEvent(type: BleDiscoveryEventType.discovered, peer: peer),
        );
      }
    }
  }

  Future<void> dispose() async {
    await stopScanning();
    await stopAdvertising();

    _peerTracker.clear();
    _currentScanPeerIds.clear();

    await _discoveredPeersController.close();
    await _discoveryEventsController.close();
  }
}
