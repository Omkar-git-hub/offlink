import 'package:flutter/material.dart';

import '../../domain/security/peer_security_repository.dart';
import '../../domain/security/safety_fingerprint_generator.dart';
import '../../domain/security/trust_status.dart';

/// Interactive modal dialog displaying the cryptographic safety fingerprint
/// for out-of-band verification between peers.
class SafetyFingerprintDialog extends StatefulWidget {
  const SafetyFingerprintDialog({
    super.key,
    required this.peerNodeId,
    required this.peerDisplayName,
    required this.localPublicKeyHex,
    required this.peerPublicKeyHex,
    required this.securityRepository,
    this.initialTrust,
  });

  final String peerNodeId;
  final String peerDisplayName;
  final String localPublicKeyHex;
  final String peerPublicKeyHex;
  final PeerSecurityRepository securityRepository;
  final PeerTrust? initialTrust;

  @override
  State<SafetyFingerprintDialog> createState() =>
      _SafetyFingerprintDialogState();
}

class _SafetyFingerprintDialogState extends State<SafetyFingerprintDialog> {
  late PeerTrust? _trust;
  String _numericFingerprint = 'Computing...';
  String _visualFingerprint = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _trust = widget.initialTrust;
    _computeAndLoadTrust();
  }

  Future<void> _computeAndLoadTrust() async {
    const generator = SafetyFingerprintGenerator();
    final numeric = await generator.generateNumericFingerprint(
      localPublicKeyHex: widget.localPublicKeyHex,
      peerPublicKeyHex: widget.peerPublicKeyHex,
    );
    final visual = await generator.generateVisualFingerprint(
      localPublicKeyHex: widget.localPublicKeyHex,
      peerPublicKeyHex: widget.peerPublicKeyHex,
    );

    final currentTrust = await widget.securityRepository.getPeerTrust(
      widget.peerNodeId,
    );

    if (mounted) {
      setState(() {
        _numericFingerprint = numeric;
        _visualFingerprint = visual;
        _trust = currentTrust ?? widget.initialTrust;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleVerification() async {
    final newStatus = _trust?.isVerified == true
        ? TrustStatus.unverified
        : TrustStatus.verified;

    await widget.securityRepository.setPeerVerificationStatus(
      widget.peerNodeId,
      newStatus,
    );

    final updated = await widget.securityRepository.getPeerTrust(
      widget.peerNodeId,
    );

    if (mounted) {
      setState(() {
        _trust = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = _trust?.isVerified ?? false;
    final isMismatched = _trust?.isMismatched ?? false;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isMismatched
                ? Icons.warning_amber_rounded
                : (isVerified ? Icons.verified_user : Icons.lock_outline),
            color: isMismatched
                ? Colors.red
                : (isVerified ? Colors.green : Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Safety Fingerprint',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compare this number with ${widget.peerDisplayName} out-of-band to ensure end-to-end security and protect against impersonation.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (isMismatched) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WARNING: This peer\'s identity public key has changed! Verify identity before continuing.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Column(
                      children: [
                        Text(
                          _numericFingerprint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (_visualFingerprint.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _visualFingerprint,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Chip(
                  avatar: Icon(
                    isVerified ? Icons.check_circle : Icons.info_outline,
                    size: 16,
                    color: isVerified ? Colors.green : Colors.grey,
                  ),
                  label: Text(
                    isVerified
                        ? 'Verified'
                        : (isMismatched ? 'Key Mismatched' : 'Unverified'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isVerified ? Colors.green.shade800 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.tonal(
          onPressed: _isLoading ? null : _toggleVerification,
          child: Text(isVerified ? 'Clear Verification' : 'Mark as Verified'),
        ),
      ],
    );
  }
}
