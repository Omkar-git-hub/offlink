import 'ble_models.dart';

enum BleDiscoveryEventType { discovered, lost }

class BleDiscoveryEvent {
  const BleDiscoveryEvent({required this.type, required this.peer});

  final BleDiscoveryEventType type;
  final BlePeer peer;
}
