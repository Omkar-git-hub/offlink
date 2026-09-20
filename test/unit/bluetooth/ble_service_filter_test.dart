import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_service_filter.dart';
import 'package:offlink/bluetooth/offlink_ble_service.dart';

void main() {
  group('BleServiceFilter', () {
    const filter = BleServiceFilter();

    test('accepts the Offlink service UUID', () {
      expect(filter.isOfflinkService(OfflinkBleService.serviceUuid), isTrue);
    });

    test('accepts the Offlink service UUID case-insensitively', () {
      expect(
        filter.isOfflinkService(OfflinkBleService.serviceUuid.toUpperCase()),
        isTrue,
      );
    });

    test('rejects an unrelated service UUID', () {
      expect(
        filter.isOfflinkService('11111111-1111-1111-1111-111111111111'),
        isFalse,
      );
    });

    test('rejects an empty UUID', () {
      expect(filter.isOfflinkService(''), isFalse);
    });
  });
}
