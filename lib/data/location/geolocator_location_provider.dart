import 'package:geolocator/geolocator.dart';

import '../../domain/location/location_provider.dart';
import '../../domain/location/position_data.dart';

/// Concrete implementation of [LocationProvider] using `package:geolocator`.
class GeolocatorLocationProvider implements LocationProvider {
  const GeolocatorLocationProvider();

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      return _mapPermission(permission);
    } catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return _mapPermission(permission);
    } catch (_) {
      return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<PositionData> getCurrentPosition({bool highAccuracy = false}) async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled on this device.');
    }

    final permission = await checkPermission();
    if (permission != LocationPermissionStatus.granted) {
      throw StateError('Location permission is not granted.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: highAccuracy
            ? LocationAccuracy.high
            : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      ),
    );

    return PositionData(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp.toUtc(),
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
    );
  }

  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }
}
