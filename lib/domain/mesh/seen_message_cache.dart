class SeenMessageCache {
  SeenMessageCache({
    this.maxCapacity = 1000,
    this.entryTtl = const Duration(seconds: 3),
  });

  final int maxCapacity;
  final Duration entryTtl;

  final Map<String, DateTime> _seenTimestamps = <String, DateTime>{};

  bool hasSeen(String messageId) {
    _pruneExpired();
    return _seenTimestamps.containsKey(messageId);
  }

  void markSeen(String messageId) {
    _pruneExpired();
    if (_seenTimestamps.length >= maxCapacity) {
      _pruneOldest();
    }
    _seenTimestamps[messageId] = DateTime.now().toUtc();
  }

  /// Atomically checks if [messageId] was seen. If not seen, records it
  /// and returns true. If already seen, returns false.
  bool markIfUnseen(String messageId) {
    _pruneExpired();
    if (_seenTimestamps.containsKey(messageId)) {
      return false;
    }
    if (_seenTimestamps.length >= maxCapacity) {
      _pruneOldest();
    }
    _seenTimestamps[messageId] = DateTime.now().toUtc();
    return true;
  }

  int get size => _seenTimestamps.length;

  void clear() {
    _seenTimestamps.clear();
  }

  void _pruneExpired() {
    final now = DateTime.now().toUtc();
    _seenTimestamps.removeWhere((_, timestamp) {
      return now.difference(timestamp) > entryTtl;
    });
  }

  void _pruneOldest() {
    if (_seenTimestamps.isEmpty) return;
    String? oldestKey;
    DateTime? oldestTime;
    for (final entry in _seenTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value;
      }
    }
    if (oldestKey != null) {
      _seenTimestamps.remove(oldestKey);
    }
  }
}
