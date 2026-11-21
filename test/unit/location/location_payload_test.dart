import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/location/location_payload.dart';

void main() {
  group('LocationSharingTypeCodec', () {
    test('encodes and decodes all sharing types', () {
      expect(LocationSharingType.oneTime.value, 'one_time');
      expect(LocationSharingType.liveUpdate.value, 'live_update');
      expect(LocationSharingType.liveStop.value, 'live_stop');

      expect(
        LocationSharingTypeCodec.fromValue('one_time'),
        LocationSharingType.oneTime,
      );
      expect(
        LocationSharingTypeCodec.fromValue('live_update'),
        LocationSharingType.liveUpdate,
      );
      expect(
        LocationSharingTypeCodec.fromValue('live_stop'),
        LocationSharingType.liveStop,
      );
    });

    test('throws FormatException on unsupported type', () {
      expect(
        () => LocationSharingTypeCodec.fromValue('invalid'),
        throwsFormatException,
      );
    });
  });

  group('LocationPayload', () {
    final now = DateTime.utc(2026, 11, 21, 10, 0, 0);

    test('serializes and deserializes a one-time snapshot correctly', () {
      final payload = LocationPayload(
        locationId: 'loc-snap-12345',
        senderNodeId: 'node-alice',
        senderDisplayName: 'Alice',
        recipientNodeId: 'node-bob',
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 12.5,
        timestamp: now,
        sharingType: LocationSharingType.oneTime,
        isLive: false,
      );

      final encoded = payload.encode();
      final decoded = LocationPayload.decode(encoded);

      expect(decoded.locationId, 'loc-snap-12345');
      expect(decoded.senderNodeId, 'node-alice');
      expect(decoded.senderDisplayName, 'Alice');
      expect(decoded.recipientNodeId, 'node-bob');
      expect(decoded.groupId, isNull);
      expect(decoded.latitude, 37.7749);
      expect(decoded.longitude, -122.4194);
      expect(decoded.accuracy, 12.5);
      expect(decoded.timestamp, now);
      expect(decoded.sharingType, LocationSharingType.oneTime);
      expect(decoded.isLive, isFalse);
      expect(decoded.liveSessionId, isNull);
      expect(decoded.expiresAt, isNull);
      expect(decoded, equals(payload));
      expect(decoded.hashCode, equals(payload.hashCode));
    });

    test('serializes and deserializes a live location update with group', () {
      final expires = now.add(const Duration(minutes: 30));
      final payload = LocationPayload(
        locationId: 'loc-upd-67890',
        senderNodeId: 'node-alice',
        senderDisplayName: 'Alice',
        groupId: 'grp-rescue-team',
        latitude: 18.5204,
        longitude: 73.8567,
        accuracy: 8.0,
        timestamp: now,
        expiresAt: expires,
        sharingType: LocationSharingType.liveUpdate,
        liveSessionId: 'live-sess-1',
        isLive: true,
      );

      final encoded = payload.encode();
      final decoded = LocationPayload.decode(encoded);

      expect(decoded.locationId, 'loc-upd-67890');
      expect(decoded.groupId, 'grp-rescue-team');
      expect(decoded.recipientNodeId, isNull);
      expect(decoded.latitude, 18.5204);
      expect(decoded.longitude, 73.8567);
      expect(decoded.accuracy, 8.0);
      expect(decoded.timestamp, now);
      expect(decoded.expiresAt, expires);
      expect(decoded.sharingType, LocationSharingType.liveUpdate);
      expect(decoded.liveSessionId, 'live-sess-1');
      expect(decoded.isLive, isTrue);
    });

    test('validates coordinate boundaries', () {
      expect(
        () => LocationPayload.fromMap({
          'latitude': 95.0,
          'longitude': 0.0,
          'timestamp': now.toIso8601String(),
        }),
        throwsFormatException,
      );

      expect(
        () => LocationPayload.fromMap({
          'latitude': -95.0,
          'longitude': 0.0,
          'timestamp': now.toIso8601String(),
        }),
        throwsFormatException,
      );

      expect(
        () => LocationPayload.fromMap({
          'latitude': 0.0,
          'longitude': 190.0,
          'timestamp': now.toIso8601String(),
        }),
        throwsFormatException,
      );

      expect(
        () => LocationPayload.fromMap({
          'latitude': 0.0,
          'longitude': -190.0,
          'timestamp': now.toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('throws when coordinates are missing or payload is non-object', () {
      expect(
        () => LocationPayload.fromMap({'timestamp': now.toIso8601String()}),
        throwsFormatException,
      );

      expect(
        () => LocationPayload.decode('["not", "an", "object"]'),
        throwsFormatException,
      );
    });

    test('isLocationMessage accurately identifies location payloads', () {
      final validLoc = LocationPayload(
        locationId: 'loc-1',
        senderNodeId: 'node-1',
        senderDisplayName: 'User',
        latitude: 10.0,
        longitude: 20.0,
        timestamp: now,
      );

      expect(LocationPayload.isLocationMessage(validLoc.encode()), isTrue);
      expect(LocationPayload.isLocationMessage('Hello there!'), isFalse);
      expect(LocationPayload.isLocationMessage('{"text": "hello"}'), isFalse);
      expect(LocationPayload.isLocationMessage('{invalid json'), isFalse);
    });

    test('isExpired checks expiration timestamp', () {
      final unexpired = LocationPayload(
        locationId: 'loc-1',
        senderNodeId: 'node-1',
        senderDisplayName: 'User',
        latitude: 10.0,
        longitude: 20.0,
        timestamp: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      expect(unexpired.isExpired(now), isFalse);
      expect(unexpired.isExpired(now.add(const Duration(minutes: 15))), isTrue);

      final noExpiry = LocationPayload(
        locationId: 'loc-2',
        senderNodeId: 'node-1',
        senderDisplayName: 'User',
        latitude: 10.0,
        longitude: 20.0,
        timestamp: now,
      );
      expect(noExpiry.isExpired(now.add(const Duration(days: 365))), isFalse);
    });
  });
}
