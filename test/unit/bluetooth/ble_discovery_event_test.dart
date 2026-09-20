import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_discovery_event.dart';
import 'package:offlink/bluetooth/ble_models.dart';

void main() {
  group('BleDiscoveryEvent', () {
    const peer = BlePeer(
      peerId: 'peer-123',
      displayName: 'Omkar',
      signalStrength: -55,
    );

    test('stores discovered event data', () {
      const event = BleDiscoveryEvent(
        type: BleDiscoveryEventType.discovered,
        peer: peer,
      );

      expect(event.type, BleDiscoveryEventType.discovered);
      expect(event.peer.peerId, 'peer-123');
      expect(event.peer.displayName, 'Omkar');
      expect(event.peer.signalStrength, -55);
    });

    test('stores lost event data', () {
      const event = BleDiscoveryEvent(
        type: BleDiscoveryEventType.lost,
        peer: peer,
      );

      expect(event.type, BleDiscoveryEventType.lost);
      expect(event.peer.peerId, 'peer-123');
    });

    test('supports both discovery event types', () {
      expect(
        BleDiscoveryEventType.values,
        containsAll([
          BleDiscoveryEventType.discovered,
          BleDiscoveryEventType.lost,
        ]),
      );
    });
  });
}
