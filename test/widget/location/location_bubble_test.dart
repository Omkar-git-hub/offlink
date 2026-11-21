import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/location/location_payload.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/features/location/location_bubble.dart';

void main() {
  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('LocationBubble Widget Tests', () {
    testWidgets(
      'renders one-time snapshot location with coordinates and accuracy',
      (tester) async {
        final payload = LocationPayload(
          locationId: 'loc-snap-1',
          senderNodeId: 'node-alice',
          senderDisplayName: 'Alice',
          recipientNodeId: 'node-bob',
          latitude: 37.7749,
          longitude: -122.4194,
          accuracy: 8.5,
          timestamp: DateTime.utc(2026, 11, 21, 10, 0),
          sharingType: LocationSharingType.oneTime,
        );

        final message = ChatMessage(
          id: 'msg-loc-1',
          conversationId: 'node-alice',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-bob',
          content: payload.encode(),
          timestamp: DateTime.utc(2026, 11, 21, 10, 0),
          isOutgoing: false,
          status: ChatMessageStatus.delivered,
        );

        await tester.pumpWidget(
          buildTestWidget(LocationBubble(message: message, payload: payload)),
        );

        expect(find.text('Location Snapshot'), findsOneWidget);
        expect(find.textContaining('37.77490°'), findsOneWidget);
        expect(find.textContaining('-122.41940°'), findsOneWidget);
        expect(find.textContaining('±9m'), findsOneWidget);
        expect(find.byIcon(Icons.location_on), findsOneWidget);
      },
    );

    testWidgets(
      'renders active live location with LIVE badge and pulse indicator',
      (tester) async {
        final expires = DateTime.now().toUtc().add(const Duration(minutes: 15));
        final payload = LocationPayload(
          locationId: 'loc-live-sess-123',
          liveSessionId: 'sess-123',
          senderNodeId: 'node-bob',
          senderDisplayName: 'Bob',
          recipientNodeId: 'node-alice',
          latitude: 40.7128,
          longitude: -74.0060,
          accuracy: 5.0,
          expiresAt: expires,
          timestamp: DateTime.now().toUtc(),
          sharingType: LocationSharingType.liveUpdate,
          isLive: true,
        );

        final message = ChatMessage(
          id: 'loc-live-sess-123',
          conversationId: 'node-bob',
          senderNodeId: 'node-bob',
          recipientNodeId: 'node-alice',
          content: payload.encode(),
          timestamp: DateTime.now().toUtc(),
          isOutgoing: true,
          status: ChatMessageStatus.sent,
        );

        await tester.pumpWidget(
          buildTestWidget(LocationBubble(message: message, payload: payload)),
        );

        expect(find.text('Live Location'), findsOneWidget);
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.textContaining('40.71280°'), findsOneWidget);
        expect(find.textContaining('-74.00600°'), findsOneWidget);
        expect(find.byIcon(Icons.my_location), findsOneWidget);
      },
    );

    testWidgets(
      'renders ended live location badge when sharingType is liveStop',
      (tester) async {
        final payload = LocationPayload(
          locationId: 'loc-live-sess-123',
          liveSessionId: 'sess-123',
          senderNodeId: 'node-bob',
          senderDisplayName: 'Bob',
          recipientNodeId: 'node-alice',
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.now().toUtc(),
          sharingType: LocationSharingType.liveStop,
          isLive: false,
        );

        final message = ChatMessage(
          id: 'loc-live-sess-123',
          conversationId: 'node-bob',
          senderNodeId: 'node-bob',
          recipientNodeId: 'node-alice',
          content: payload.encode(),
          timestamp: DateTime.now().toUtc(),
          isOutgoing: false,
          status: ChatMessageStatus.delivered,
        );

        await tester.pumpWidget(
          buildTestWidget(LocationBubble(message: message, payload: payload)),
        );

        expect(find.text('Live Location (Ended)'), findsOneWidget);
        expect(find.byIcon(Icons.location_off), findsOneWidget);
      },
    );

    testWidgets('tapping bubble opens details dialog with copy option', (
      tester,
    ) async {
      final payload = LocationPayload(
        locationId: 'loc-snap-1',
        senderNodeId: 'node-alice',
        senderDisplayName: 'Alice',
        recipientNodeId: 'node-bob',
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 10.0,
        timestamp: DateTime.utc(2026, 11, 21, 10, 0),
        sharingType: LocationSharingType.oneTime,
      );

      final message = ChatMessage(
        id: 'msg-loc-1',
        conversationId: 'node-alice',
        senderNodeId: 'node-alice',
        recipientNodeId: 'node-bob',
        content: payload.encode(),
        timestamp: DateTime.utc(2026, 11, 21, 10, 0),
        isOutgoing: false,
        status: ChatMessageStatus.delivered,
      );

      await tester.pumpWidget(
        buildTestWidget(LocationBubble(message: message, payload: payload)),
      );

      // Tap on the bubble to trigger showDialog
      await tester.tap(find.byType(LocationBubble));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Shared by: Alice'), findsOneWidget);
      expect(find.text('Copy Coordinates'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
