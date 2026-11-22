class _PeerRateState {
  _PeerRateState({required this.firstSeen});

  final DateTime firstSeen;
  final List<DateTime> packetTimestamps = [];
  int violationCount = 0;
  DateTime? quarantinedUntil;
}

/// Inbound sliding-window flood rate limiter per node ID.
/// Protects radio, CPU, memory, and SQLite storage against packet flooding attacks.
class FloodRateLimiter {
  FloodRateLimiter({
    this.maxPacketsPerWindow = 15,
    this.windowDuration = const Duration(seconds: 3),
    this.quarantineThreshold = 3,
    this.quarantineDuration = const Duration(seconds: 30),
  });

  final int maxPacketsPerWindow;
  final Duration windowDuration;
  final int quarantineThreshold;
  final Duration quarantineDuration;

  final Map<String, _PeerRateState> _peerStates = {};

  /// Checks whether an inbound packet from [senderNodeId] is allowed.
  /// Returns `true` if allowed, `false` if dropped due to rate limit or quarantine.
  bool allowPacket(String senderNodeId, {DateTime? now}) {
    if (senderNodeId.trim().isEmpty) {
      return false;
    }

    final currentTime = now ?? DateTime.now().toUtc();
    final state = _peerStates.putIfAbsent(
      senderNodeId,
      () => _PeerRateState(firstSeen: currentTime),
    );

    // Check active quarantine
    if (state.quarantinedUntil != null) {
      if (currentTime.isBefore(state.quarantinedUntil!)) {
        return false;
      }
      // Quarantine expired; reset violations and clear quarantine
      state.quarantinedUntil = null;
      state.violationCount = 0;
      state.packetTimestamps.clear();
    }

    // Prune timestamps older than windowDuration
    final cutoff = currentTime.subtract(windowDuration);
    state.packetTimestamps.removeWhere((t) => t.isBefore(cutoff));

    // Check packet count within sliding window
    if (state.packetTimestamps.length >= maxPacketsPerWindow) {
      state.violationCount += 1;
      if (state.violationCount >= quarantineThreshold) {
        state.quarantinedUntil = currentTime.add(quarantineDuration);
      }
      return false;
    }

    state.packetTimestamps.add(currentTime);
    return true;
  }

  /// Checks whether [senderNodeId] is currently in quarantine backoff.
  bool isQuarantined(String senderNodeId, {DateTime? now}) {
    final state = _peerStates[senderNodeId];
    if (state == null || state.quarantinedUntil == null) {
      return false;
    }

    final currentTime = now ?? DateTime.now().toUtc();
    if (currentTime.isBefore(state.quarantinedUntil!)) {
      return true;
    }

    state.quarantinedUntil = null;
    return false;
  }

  /// Resets rate tracking and quarantine for a specific peer.
  void reset(String senderNodeId) {
    _peerStates.remove(senderNodeId);
  }

  /// Resets all peer rate tracking.
  void resetAll() {
    _peerStates.clear();
  }

  /// Prunes inactive peer states older than [maxAge] to enforce bounded memory usage.
  void pruneStale({
    DateTime? now,
    Duration maxAge = const Duration(minutes: 2),
  }) {
    final currentTime = now ?? DateTime.now().toUtc();
    final cutoff = currentTime.subtract(maxAge);

    _peerStates.removeWhere((_, state) {
      if (state.quarantinedUntil != null &&
          currentTime.isBefore(state.quarantinedUntil!)) {
        return false;
      }
      if (state.packetTimestamps.isEmpty) {
        return true;
      }
      return state.packetTimestamps.last.isBefore(cutoff);
    });
  }

  int get trackedPeersCount => _peerStates.length;
}
