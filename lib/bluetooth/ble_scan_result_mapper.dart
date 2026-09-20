import 'ble_models.dart';
import 'ble_scan_data.dart';
import 'ble_service_filter.dart';

class BleScanResultMapper {
  const BleScanResultMapper({required this._serviceFilter});

  final BleServiceFilter _serviceFilter;

  BlePeer? map(BleScanData scanData) {
    final isOfflinkDevice = scanData.serviceUuids.any(
      _serviceFilter.isOfflinkService,
    );

    if (!isOfflinkDevice) {
      return null;
    }

    return BlePeer(
      peerId: scanData.peerId,
      displayName: scanData.displayName,
      signalStrength: scanData.signalStrength,
    );
  }
}
