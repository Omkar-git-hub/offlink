import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/ble_scan_data.dart';
import 'package:offlink/bluetooth/ble_scan_result_mapper.dart';
import 'package:offlink/bluetooth/ble_service_filter.dart';
import 'package:offlink/bluetooth/offlink_ble_service.dart';

void main() {
  const mapper = BleScanResultMapper(serviceFilter: BleServiceFilter());

  group('BleScanResultMapper', () {
    test('maps an Offlink scan result to BlePeer', () {
      const scanData = BleScanData(
        peerId: 'peer-123',
        displayName: 'Omkar',
        signalStrength: -55,
        serviceUuids: [OfflinkBleService.serviceUuid],
      );

      final peer = mapper.map(scanData);

      expect(peer, isNotNull);
      expect(peer!.peerId, 'peer-123');
      expect(peer.displayName, 'Omkar');
      expect(peer.signalStrength, -55);
    });

    test('returns null for a non-Offlink device', () {
      const scanData = BleScanData(
        peerId: 'peer-456',
        displayName: 'Other Device',
        signalStrength: -70,
        serviceUuids: ['11111111-1111-1111-1111-111111111111'],
      );

      expect(mapper.map(scanData), isNull);
    });

    test('accepts Offlink service among multiple services', () {
      const scanData = BleScanData(
        peerId: 'peer-789',
        displayName: 'Nearby Offlink',
        signalStrength: -60,
        serviceUuids: [
          '11111111-1111-1111-1111-111111111111',
          OfflinkBleService.serviceUuid,
          '22222222-2222-2222-2222-222222222222',
        ],
      );

      final peer = mapper.map(scanData);

      expect(peer, isNotNull);
      expect(peer!.peerId, 'peer-789');
    });

    test('returns null when no services are advertised', () {
      const scanData = BleScanData(
        peerId: 'peer-empty',
        displayName: 'Unknown',
        signalStrength: -80,
        serviceUuids: [],
      );

      expect(mapper.map(scanData), isNull);
    });

    test('preserves peer information from scan data', () {
      const scanData = BleScanData(
        peerId: 'node-abc',
        displayName: 'Test Node',
        signalStrength: -42,
        serviceUuids: [OfflinkBleService.serviceUuid],
      );

      final BlePeer? peer = mapper.map(scanData);

      expect(peer, isA<BlePeer>());
      expect(peer!.peerId, scanData.peerId);
      expect(peer.displayName, scanData.displayName);
      expect(peer.signalStrength, scanData.signalStrength);
    });
  });
}
