import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_discovery_event.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/phone_ble_discovery.dart';

import 'fakes/fake_ble_advertiser.dart';
import 'fakes/fake_ble_scanner.dart';

void main() {
  group('PhoneBleDiscovery', () {
    test('starts scanning successfully', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.startScanning();

      expect(scanner.startCalled, isTrue);
      expect(scanner.startedWithServices, isNotEmpty);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('start scanning is idempotent', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.startScanning();
      await discovery.startScanning();

      expect(scanner.startCalled, isTrue);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('stop scanning is safe before start', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.stopScanning();

      expect(scanner.stopCalled, isFalse);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('stopping scanning twice is safe', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.startScanning();
      await discovery.stopScanning();
      await discovery.stopScanning();

      expect(scanner.stopCalled, isTrue);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('starts advertising successfully', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.startAdvertising();

      expect(advertiser.startCalled, isTrue);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('starting advertising twice is safe', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.startAdvertising();
      await discovery.startAdvertising();

      expect(advertiser.startCalled, isTrue);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('stops advertising safely before start', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.stopAdvertising();

      expect(advertiser.stopCalled, isFalse);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('stopping advertising twice is safe', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.startAdvertising();
      await discovery.stopAdvertising();
      await discovery.stopAdvertising();

      expect(advertiser.startCalled, isTrue);
      expect(advertiser.stopCalled, isTrue);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('exposes discovered peers stream', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      expect(discovery.discoveredPeers, isA<Stream<BlePeer>>());

      await discovery.dispose();
      await scanner.dispose();
    });

    test('exposes discovery events stream', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      expect(discovery.discoveryEvents, isA<Stream<BleDiscoveryEvent>>());

      await discovery.dispose();
      await scanner.dispose();
    });

    test('recognizes the Offlink service', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      expect(
        discovery.isOfflinkService('00000000-0000-0000-0000-000000000000'),
        isTrue,
      );

      await discovery.dispose();
      await scanner.dispose();
    });

    test('rejects an unrelated service', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      expect(
        discovery.isOfflinkService('11111111-1111-1111-1111-111111111111'),
        isFalse,
      );

      await discovery.dispose();
      await scanner.dispose();
    });

    test('complete scan cycle returns no lost peers initially', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      final lostPeerIds = await discovery.completeScanCycle();

      expect(lostPeerIds, isEmpty);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('complete scan cycle clears the current scan cycle', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      await discovery.startScanning();

      final firstCycleLostPeerIds = await discovery.completeScanCycle();

      final secondCycleLostPeerIds = await discovery.completeScanCycle();

      expect(firstCycleLostPeerIds, isEmpty);
      expect(secondCycleLostPeerIds, isEmpty);

      await discovery.dispose();
      await scanner.dispose();
    });

    test('discovery events stream supports discovered events', () async {
      final scanner = FakeBleScanner();
      final advertiser = FakeBleAdvertiser();

      final discovery = PhoneBleDiscovery(
        scanner: scanner,
        advertiser: advertiser,
      );

      final events = <BleDiscoveryEvent>[];
      final subscription = discovery.discoveryEvents.listen(events.add);

      await discovery.startScanning();

      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      await discovery.dispose();
      await scanner.dispose();

      expect(events, isEmpty);
    });
  });

  test('starts scanning with the Offlink service UUID', () async {
    final scanner = FakeBleScanner();
    final advertiser = FakeBleAdvertiser();

    final discovery = PhoneBleDiscovery(
      scanner: scanner,
      advertiser: advertiser,
    );

    await discovery.startScanning();

    expect(scanner.startedWithServices, hasLength(1));

    expect(
      scanner.startedWithServices.first.toString().toLowerCase(),
      '00000000-0000-0000-0000-000000000000',
    );

    await discovery.dispose();
    await scanner.dispose();
  });
}
