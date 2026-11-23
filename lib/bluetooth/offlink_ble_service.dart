class OfflinkBleService {
  const OfflinkBleService._();

  /// Dedicated 128-bit RFC 4122 v4 Service UUID for Offlink BLE transport.
  static const String serviceUuid = '0f110001-4000-4000-8000-000000000000';

  /// Control characteristic UUID for handshakes and control signals.
  static const String controlCharacteristicUuid =
      '0f110002-4000-4000-8000-000000000000';

  /// TX characteristic UUID (peripheral notifies, central listens).
  static const String txCharacteristicUuid =
      '0f110003-4000-4000-8000-000000000000';

  /// RX characteristic UUID (central writes, peripheral receives).
  static const String rxCharacteristicUuid =
      '0f110004-4000-4000-8000-000000000000';

  /// Offlink 16-bit manufacturer identifier for identity advertising in scan responses.
  static const int manufacturerId = 0x0F11;
}
