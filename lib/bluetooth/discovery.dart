import 'ble_models.dart';
import 'ble_discovery_event.dart';

abstract interface class BleDiscovery {
  Future<void> startScanning();

  Future<void> stopScanning();

  Future<void> startAdvertising();

  Future<void> stopAdvertising();

  Future<Set<String>> completeScanCycle();

  Stream<BlePeer> get discoveredPeers;

  Stream<BleDiscoveryEvent> get discoveryEvents;
}
