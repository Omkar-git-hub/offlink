enum TrustStatus {
  unverified,
  verified,
  mismatched;

  static TrustStatus fromString(String value) {
    return switch (value.toLowerCase()) {
      'verified' => TrustStatus.verified,
      'mismatched' => TrustStatus.mismatched,
      _ => TrustStatus.unverified,
    };
  }
}

class PeerTrust {
  const PeerTrust({
    required this.peerNodeId,
    required this.peerPublicKey,
    required this.safetyFingerprint,
    required this.trustStatus,
    required this.updatedAt,
    this.verifiedAt,
  });

  final String peerNodeId;
  final String peerPublicKey;
  final String safetyFingerprint;
  final TrustStatus trustStatus;
  final DateTime? verifiedAt;
  final DateTime updatedAt;

  bool get isVerified => trustStatus == TrustStatus.verified;
  bool get isMismatched => trustStatus == TrustStatus.mismatched;

  PeerTrust copyWith({
    String? peerNodeId,
    String? peerPublicKey,
    String? safetyFingerprint,
    TrustStatus? trustStatus,
    DateTime? verifiedAt,
    DateTime? updatedAt,
  }) {
    return PeerTrust(
      peerNodeId: peerNodeId ?? this.peerNodeId,
      peerPublicKey: peerPublicKey ?? this.peerPublicKey,
      safetyFingerprint: safetyFingerprint ?? this.safetyFingerprint,
      trustStatus: trustStatus ?? this.trustStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BlockedPeer {
  const BlockedPeer({
    required this.nodeId,
    required this.blockedAt,
    this.reason = 'manual',
  });

  final String nodeId;
  final DateTime blockedAt;
  final String reason;
}
