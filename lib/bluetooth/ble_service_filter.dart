import 'offlink_ble_service.dart';

class BleServiceFilter {
  const BleServiceFilter();

  bool isOfflinkService(String serviceUuid) {
    if (serviceUuid.isEmpty) {
      return false;
    }
    return _normalize(serviceUuid) == _normalize(OfflinkBleService.serviceUuid);
  }

  static String _normalize(String uuid) {
    return uuid.replaceAll('-', '').toLowerCase();
  }
}
