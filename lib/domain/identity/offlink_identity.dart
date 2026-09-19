class OfflinkIdentity {
  const OfflinkIdentity({
    required this.nodeId,
    required this.username,
    required this.publicKey,
    required this.createdAt,
  });

  final String nodeId;
  final String username;
  final String publicKey;
  final DateTime createdAt;

  OfflinkIdentity copyWith({
    String? nodeId,
    String? username,
    String? publicKey,
    DateTime? createdAt,
  }) {
    return OfflinkIdentity(
      nodeId: nodeId ?? this.nodeId,
      username: username ?? this.username,
      publicKey: publicKey ?? this.publicKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
