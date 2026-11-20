class RouteEntry {
  const RouteEntry({
    required this.destinationNodeId,
    required this.nextHopPeerId,
    required this.hopCount,
    required this.updatedAt,
  });

  final String destinationNodeId;
  final String nextHopPeerId;
  final int hopCount;
  final DateTime updatedAt;

  RouteEntry copyWith({
    String? destinationNodeId,
    String? nextHopPeerId,
    int? hopCount,
    DateTime? updatedAt,
  }) {
    return RouteEntry(
      destinationNodeId: destinationNodeId ?? this.destinationNodeId,
      nextHopPeerId: nextHopPeerId ?? this.nextHopPeerId,
      hopCount: hopCount ?? this.hopCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class RoutingTable {
  RoutingTable({this.routeLifetime = const Duration(minutes: 15)});

  final Duration routeLifetime;
  final Map<String, RouteEntry> _routes = <String, RouteEntry>{};

  void updateRoute({
    required String destinationNodeId,
    required String nextHopPeerId,
    required int hopCount,
  }) {
    final now = DateTime.now().toUtc();
    final existing = _routes[destinationNodeId];

    if (existing == null) {
      _routes[destinationNodeId] = RouteEntry(
        destinationNodeId: destinationNodeId,
        nextHopPeerId: nextHopPeerId,
        hopCount: hopCount,
        updatedAt: now,
      );
      return;
    }

    // Update if shorter path, or refresh timestamp if same next hop,
    // or if the previous route has expired.
    final isExpired = now.difference(existing.updatedAt) > routeLifetime;
    if (isExpired ||
        hopCount < existing.hopCount ||
        existing.nextHopPeerId == nextHopPeerId) {
      _routes[destinationNodeId] = RouteEntry(
        destinationNodeId: destinationNodeId,
        nextHopPeerId: nextHopPeerId,
        hopCount: hopCount,
        updatedAt: now,
      );
    }
  }

  RouteEntry? getRoute(String destinationNodeId) {
    _pruneExpired();
    return _routes[destinationNodeId];
  }

  bool hasRoute(String destinationNodeId) {
    _pruneExpired();
    return _routes.containsKey(destinationNodeId);
  }

  void removeRoute(String destinationNodeId) {
    _routes.remove(destinationNodeId);
  }

  void removeRoutesForPeer(String peerId) {
    _routes.removeWhere((_, entry) => entry.nextHopPeerId == peerId);
  }

  List<RouteEntry> get allRoutes {
    _pruneExpired();
    return _routes.values.toList();
  }

  int get size {
    _pruneExpired();
    return _routes.length;
  }

  void clear() {
    _routes.clear();
  }

  void _pruneExpired() {
    final now = DateTime.now().toUtc();
    _routes.removeWhere((_, entry) {
      return now.difference(entry.updatedAt) > routeLifetime;
    });
  }
}
