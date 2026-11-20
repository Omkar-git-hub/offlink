/// Role of a member inside a group.
enum GroupMemberRole {
  admin,
  member;

  static GroupMemberRole fromString(String value) {
    return value.toLowerCase() == 'admin'
        ? GroupMemberRole.admin
        : GroupMemberRole.member;
  }
}

/// Domain entity representing a member of a group chat.
class GroupMember {
  const GroupMember({
    required this.groupId,
    required this.memberNodeId,
    required this.memberDisplayName,
    this.role = GroupMemberRole.member,
    required this.joinedAt,
  });

  /// The group ID this membership belongs to.
  final String groupId;

  /// Unique node ID of the member.
  final String memberNodeId;

  /// Human-readable display name of the member.
  final String memberDisplayName;

  /// Role of the member within the group (admin or member).
  final GroupMemberRole role;

  /// Timestamp when the member joined the group (UTC).
  final DateTime joinedAt;

  GroupMember copyWith({
    String? groupId,
    String? memberNodeId,
    String? memberDisplayName,
    GroupMemberRole? role,
    DateTime? joinedAt,
  }) {
    return GroupMember(
      groupId: groupId ?? this.groupId,
      memberNodeId: memberNodeId ?? this.memberNodeId,
      memberDisplayName: memberDisplayName ?? this.memberDisplayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'memberNodeId': memberNodeId,
      'memberDisplayName': memberDisplayName,
      'role': role.name,
      'joinedAt': joinedAt.toUtc().toIso8601String(),
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      groupId: map['groupId'] as String,
      memberNodeId: map['memberNodeId'] as String,
      memberDisplayName: map['memberDisplayName'] as String,
      role: GroupMemberRole.fromString(map['role'] as String? ?? 'member'),
      joinedAt: DateTime.parse(map['joinedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          memberNodeId == other.memberNodeId &&
          memberDisplayName == other.memberDisplayName &&
          role == other.role &&
          joinedAt == other.joinedAt;

  @override
  int get hashCode =>
      groupId.hashCode ^
      memberNodeId.hashCode ^
      memberDisplayName.hashCode ^
      role.hashCode ^
      joinedAt.hashCode;
}
