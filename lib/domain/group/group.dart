/// Domain entity representing a group chat in Offlink.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.creatorNodeId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Unique identifier for the group (e.g. `group-<timestamp>-<hash>`).
  final String id;

  /// Human-readable group name.
  final String name;

  /// Node ID of the member who created this group.
  final String creatorNodeId;

  /// Timestamp when the group was created (UTC).
  final DateTime createdAt;

  /// Timestamp when the group was last updated (UTC).
  final DateTime updatedAt;

  Group copyWith({
    String? id,
    String? name,
    String? creatorNodeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorNodeId: creatorNodeId ?? this.creatorNodeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          creatorNodeId == other.creatorNodeId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      creatorNodeId.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
