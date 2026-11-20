import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/mesh/routing_table.dart';

void main() {
  group('RoutingTable', () {
    test('adds and retrieves route entries', () {
      final table = RoutingTable();

      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-bob',
        hopCount: 2,
      );

      expect(table.hasRoute('node-charlie'), isTrue);
      final route = table.getRoute('node-charlie');
      expect(route, isNotNull);
      expect(route!.destinationNodeId, equals('node-charlie'));
      expect(route.nextHopPeerId, equals('peer-bob'));
      expect(route.hopCount, equals(2));
    });

    test('updates route when a shorter path is discovered', () {
      final table = RoutingTable();

      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-bob',
        hopCount: 3,
      );

      // Shorter route via peer-dave
      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-dave',
        hopCount: 2,
      );

      final route = table.getRoute('node-charlie');
      expect(route!.nextHopPeerId, equals('peer-dave'));
      expect(route.hopCount, equals(2));
    });

    test('ignores longer paths from other peers for existing route', () {
      final table = RoutingTable();

      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-dave',
        hopCount: 2,
      );

      // Longer path from peer-bob
      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-bob',
        hopCount: 4,
      );

      final route = table.getRoute('node-charlie');
      expect(route!.nextHopPeerId, equals('peer-dave'));
      expect(route.hopCount, equals(2));
    });

    test('refreshes timestamp when same next hop reports route', () {
      final table = RoutingTable();

      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-bob',
        hopCount: 2,
      );

      final initialTime = table.getRoute('node-charlie')!.updatedAt;

      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-bob',
        hopCount: 2,
      );

      final refreshedTime = table.getRoute('node-charlie')!.updatedAt;
      expect(
        refreshedTime.isAfter(initialTime) ||
            refreshedTime.isAtSameMomentAs(initialTime),
        isTrue,
      );
    });

    test('removeRoutesForPeer removes all dependent next-hop routes', () {
      final table = RoutingTable();

      table.updateRoute(
        destinationNodeId: 'node-bob',
        nextHopPeerId: 'peer-bob',
        hopCount: 1,
      );
      table.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'peer-bob',
        hopCount: 2,
      );
      table.updateRoute(
        destinationNodeId: 'node-dave',
        nextHopPeerId: 'peer-dave',
        hopCount: 1,
      );

      expect(table.size, equals(3));

      // Bob disconnects: remove all routes passing through Bob
      table.removeRoutesForPeer('peer-bob');

      expect(table.hasRoute('node-bob'), isFalse);
      expect(table.hasRoute('node-charlie'), isFalse);
      expect(table.hasRoute('node-dave'), isTrue);
      expect(table.size, equals(1));
    });

    test('prunes expired routes after routeLifetime', () async {
      final table = RoutingTable(
        routeLifetime: const Duration(milliseconds: 50),
      );

      table.updateRoute(
        destinationNodeId: 'node-temp',
        nextHopPeerId: 'peer-temp',
        hopCount: 1,
      );

      expect(table.hasRoute('node-temp'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(table.hasRoute('node-temp'), isFalse);
      expect(table.getRoute('node-temp'), isNull);
      expect(table.size, equals(0));
    });

    test('clear removes all routes', () {
      final table = RoutingTable();
      table.updateRoute(
        destinationNodeId: 'n1',
        nextHopPeerId: 'p1',
        hopCount: 1,
      );
      table.updateRoute(
        destinationNodeId: 'n2',
        nextHopPeerId: 'p2',
        hopCount: 1,
      );
      expect(table.size, equals(2));

      table.clear();
      expect(table.size, equals(0));
    });
  });
}
