import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/location/location_provider.dart';
import 'package:offlink/domain/location/location_service.dart';
import 'package:offlink/domain/location/position_data.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/features/location/location_sharing_sheet.dart';

class _FakeLocationProvider implements LocationProvider {
  _FakeLocationProvider();

  bool serviceEnabled = true;
  LocationPermissionStatus status = LocationPermissionStatus.granted;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      serviceEnabled ? status : LocationPermissionStatus.serviceDisabled;

  @override
  Future<LocationPermissionStatus> requestPermission() async => status;

  @override
  Future<PositionData> getCurrentPosition({bool highAccuracy = false}) async =>
      PositionData(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.0,
        timestamp: DateTime.now().toUtc(),
      );
}

class _FakeTransport implements PacketTransport {
  final StreamController<OfflinkPacket> _controller =
      StreamController<OfflinkPacket>.broadcast();

  @override
  Stream<OfflinkPacket> get incomingPackets => _controller.stream;

  @override
  List<String> get connectedPeerIds => ['node-alice'];

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {}

  void dispose() {
    _controller.close();
  }
}

class _FakeIdentityManager implements IdentityManager {
  @override
  OfflinkIdentity? get currentIdentity => OfflinkIdentity(
    nodeId: 'local-node',
    username: 'Me',
    publicKey: 'pub-key',
    createdAt: DateTime.now().toUtc(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeLocationProvider locationProvider;
  late _FakeTransport transport;
  late LocationService locationService;

  setUp(() {
    locationProvider = _FakeLocationProvider();
    transport = _FakeTransport();
    locationService = LocationService(
      locationProvider: locationProvider,
      packetTransport: transport,
      identityManager: _FakeIdentityManager(),
    );
  });

  tearDown(() {
    locationService.dispose();
    transport.dispose();
  });

  Widget buildTestWidget({
    required String targetId,
    required String targetName,
    required bool isGroup,
    int? memberCount,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LocationSharingSheet(
          locationService: locationService,
          targetId: targetId,
          targetName: targetName,
          isGroup: isGroup,
          memberCount: memberCount,
        ),
      ),
    );
  }

  group('LocationSharingSheet Widget Tests', () {
    testWidgets('renders recipient disclosure for 1-to-1 chat', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          targetId: 'node-alice',
          targetName: 'Alice',
          isGroup: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Sharing'), findsOneWidget);
      expect(find.text('Sharing with: Alice'), findsOneWidget);
      expect(
        find.textContaining('End-to-end encrypted pairwise'),
        findsOneWidget,
      );
    });

    testWidgets('renders recipient disclosure for group chat', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          targetId: 'grp-123',
          targetName: 'Developers',
          isGroup: true,
          memberCount: 5,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Sharing'), findsOneWidget);
      expect(
        find.text('Sharing with group: Developers (5 members)'),
        findsOneWidget,
      );
    });

    testWidgets('renders warning card when permission is denied', (
      tester,
    ) async {
      locationProvider.status = LocationPermissionStatus.denied;

      await tester.pumpWidget(
        buildTestWidget(
          targetId: 'node-alice',
          targetName: 'Alice',
          isGroup: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Permission Needed'), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
    });

    testWidgets('renders warning card when location service is disabled', (
      tester,
    ) async {
      locationProvider.serviceEnabled = false;

      await tester.pumpWidget(
        buildTestWidget(
          targetId: 'node-alice',
          targetName: 'Alice',
          isGroup: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location Services Disabled'), findsOneWidget);
      expect(find.text('Check Again'), findsOneWidget);
    });

    testWidgets(
      'renders snapshot and live options when permission is granted',
      (tester) async {
        locationProvider.status = LocationPermissionStatus.granted;

        await tester.pumpWidget(
          buildTestWidget(
            targetId: 'node-alice',
            targetName: 'Alice',
            isGroup: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Share Current Location'), findsOneWidget);
        expect(find.text('Send'), findsOneWidget);

        expect(find.text('Share Live Location'), findsOneWidget);
        expect(find.text('15 min'), findsOneWidget);
        expect(find.text('30 min'), findsOneWidget);
        expect(find.text('1 hour'), findsOneWidget);
        expect(find.text('Start Live Sharing (15m)'), findsOneWidget);
      },
    );

    testWidgets('can change live sharing duration via SegmentedButton', (
      tester,
    ) async {
      locationProvider.status = LocationPermissionStatus.granted;

      await tester.pumpWidget(
        buildTestWidget(
          targetId: 'node-alice',
          targetName: 'Alice',
          isGroup: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Live Sharing (15m)'), findsOneWidget);

      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();

      expect(find.text('Start Live Sharing (30m)'), findsOneWidget);

      await tester.tap(find.text('1 hour'));
      await tester.pumpAndSettle();

      expect(find.text('Start Live Sharing (60m)'), findsOneWidget);
    });

    testWidgets(
      'renders active live sharing card and stop button when active',
      (tester) async {
        locationProvider.status = LocationPermissionStatus.granted;

        // Start live location
        await locationService.startLiveLocation(
          targetId: 'node-alice',
          isGroup: false,
          duration: const Duration(minutes: 30),
        );

        await tester.pumpWidget(
          buildTestWidget(
            targetId: 'node-alice',
            targetName: 'Alice',
            isGroup: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Live Location is Active'), findsOneWidget);
        expect(find.text('Stop Live Sharing'), findsOneWidget);

        await locationService.stopLiveLocation('node-alice');
      },
    );
  });
}
