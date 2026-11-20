import 'dart:convert';

import '../group/group_member.dart';

/// Payload structure for group membership control events (invites, member adds, member removes).
class GroupMembershipPayload {
  const GroupMembershipPayload({
    required this.groupId,
    required this.groupName,
    required this.action,
    required this.adminNodeId,
    required this.targetNodeId,
    required this.members,
    required this.timestamp,
  });

  /// Identifier of the target group.
  final String groupId;

  /// Name of the group.
  final String groupName;

  /// Control action: 'create', 'add', 'remove', or 'leave'.
  final String action;

  /// Node ID of the admin or sender issuing this action.
  final String adminNodeId;

  /// Node ID of the target member being added/removed.
  final String targetNodeId;

  /// Current known membership list of the group.
  final List<GroupMember> members;

  /// Timestamp when the action was taken (UTC).
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'action': action,
      'adminNodeId': adminNodeId,
      'targetNodeId': targetNodeId,
      'members': members.map((m) => m.toMap()).toList(),
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  String encode() => jsonEncode(toMap());

  factory GroupMembershipPayload.fromMap(Map<String, dynamic> map) {
    final membersRaw = (map['members'] as List<dynamic>?) ?? [];
    return GroupMembershipPayload(
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      action: map['action'] as String,
      adminNodeId: map['adminNodeId'] as String,
      targetNodeId: map['targetNodeId'] as String,
      members: membersRaw
          .map((m) => GroupMember.fromMap(m as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  factory GroupMembershipPayload.decode(String jsonString) {
    return GroupMembershipPayload.fromMap(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
