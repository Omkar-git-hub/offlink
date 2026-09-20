import 'offlink_ble_service.dart';

class BleServiceFilter {
  const BleServiceFilter();

  bool isOfflinkService(String serviceUuid) {
    return serviceUuid.toLowerCase() ==
        OfflinkBleService.serviceUuid.toLowerCase();
  }
}
