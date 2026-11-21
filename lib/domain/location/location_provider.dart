import 'position_data.dart';

/// Permission status for location services.
enum LocationPermissionStatus {
  /// Permission has been granted for foreground location access.
  granted,

  /// Permission was denied by the user.
  denied,

  /// Permission was permanently denied by the user and must be opened in settings.
  deniedForever,

  /// Location hardware/services (GPS) are disabled on the device.
  serviceDisabled,
}

/// Abstract contract for device location queries.
///
/// Implementations adapt platform location APIs (e.g., Geolocator) or
/// provide deterministic test mocks without requiring physical GPS hardware.
abstract class LocationProvider {
  /// Returns whether device location services (GPS/network) are enabled.
  Future<bool> isLocationServiceEnabled();

  /// Checks the current location permission status without prompting.
  Future<LocationPermissionStatus> checkPermission();

  /// Requests location permission from the user.
  Future<LocationPermissionStatus> requestPermission();

  /// Obtains the current device position.
  Future<PositionData> getCurrentPosition({bool highAccuracy = false});
}
