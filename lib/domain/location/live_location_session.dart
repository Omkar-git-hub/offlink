import 'position_data.dart';

/// Tracks an active live location sharing session initiated by the local user.
class LiveLocationSession {
  const LiveLocationSession({
    required this.id,
    required this.targetId,
    required this.isGroup,
    required this.startedAt,
    required this.duration,
    required this.expiresAt,
    this.isActive = true,
    this.lastPosition,
    this.lastSentAt,
  });

  /// Unique session identifier.
  final String id;

  /// Identifier of the target peer (nodeId) or group (groupId).
  final String targetId;

  /// Whether the session is shared to a group (`true`) or direct contact (`false`).
  final bool isGroup;

  /// Timestamp when sharing began (UTC).
  final DateTime startedAt;

  /// Configured total duration of the session.
  final Duration duration;

  /// Timestamp when sharing expires (UTC).
  final DateTime expiresAt;

  /// Whether live sharing is currently active.
  final bool isActive;

  /// Last measured position data sent for this session.
  final PositionData? lastPosition;

  /// Timestamp of the last transmitted position update.
  final DateTime? lastSentAt;

  /// Returns whether this session has expired relative to [now].
  bool isExpired([DateTime? now]) {
    final current = (now ?? DateTime.now()).toUtc();
    return current.isAfter(expiresAt);
  }

  /// Remaining duration before expiration. Returns [Duration.zero] if expired.
  Duration remainingTime([DateTime? now]) {
    final current = (now ?? DateTime.now()).toUtc();
    final remaining = expiresAt.difference(current);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  LiveLocationSession copyWith({
    String? id,
    String? targetId,
    bool? isGroup,
    DateTime? startedAt,
    Duration? duration,
    DateTime? expiresAt,
    bool? isActive,
    PositionData? lastPosition,
    DateTime? lastSentAt,
  }) {
    return LiveLocationSession(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      isGroup: isGroup ?? this.isGroup,
      startedAt: startedAt ?? this.startedAt,
      duration: duration ?? this.duration,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      lastPosition: lastPosition ?? this.lastPosition,
      lastSentAt: lastSentAt ?? this.lastSentAt,
    );
  }
}
