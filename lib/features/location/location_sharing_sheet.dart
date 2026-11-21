import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/location/live_location_session.dart';
import '../../domain/location/location_provider.dart';
import '../../domain/location/location_service.dart';

/// Modal bottom sheet providing transparent, user-controlled location sharing.
class LocationSharingSheet extends StatefulWidget {
  const LocationSharingSheet({
    super.key,
    required this.locationService,
    required this.targetId,
    required this.targetName,
    required this.isGroup,
    this.memberCount,
  });

  final LocationService locationService;
  final String targetId;
  final String targetName;
  final bool isGroup;
  final int? memberCount;

  static Future<void> show({
    required BuildContext context,
    required LocationService locationService,
    required String targetId,
    required String targetName,
    required bool isGroup,
    int? memberCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSharingSheet(
        locationService: locationService,
        targetId: targetId,
        targetName: targetName,
        isGroup: isGroup,
        memberCount: memberCount,
      ),
    );
  }

  @override
  State<LocationSharingSheet> createState() => _LocationSharingSheetState();
}

class _LocationSharingSheetState extends State<LocationSharingSheet> {
  LocationPermissionStatus? _permissionStatus;
  bool _isLoading = false;
  String? _errorMessage;
  Duration _selectedDuration = const Duration(minutes: 15);
  StreamSubscription<List<LiveLocationSession>>? _sessionsSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _sessionsSubscription = widget.locationService.activeSessionsStream.listen((
      _,
    ) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    setState(() => _isLoading = true);
    final status = await widget.locationService.checkPermission();
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    final status = await widget.locationService.requestPermission();
    if (!mounted) return;
    setState(() {
      _permissionStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _shareSnapshot() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.locationService.sendOneTimeLocation(
        targetId: widget.targetId,
        isGroup: widget.isGroup,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location snapshot sent successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startLiveSharing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.locationService.startLiveLocation(
        targetId: widget.targetId,
        isGroup: widget.isGroup,
        duration: _selectedDuration,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Live location sharing started for ${_selectedDuration.inMinutes} minutes.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _stopLiveSharing() async {
    setState(() => _isLoading = true);
    try {
      await widget.locationService.stopLiveLocation(
        widget.targetId,
        sendStopPacket: true,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live location sharing stopped.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSession = widget.locationService.getActiveLiveSession(
      widget.targetId,
    );
    final isLiveActive = activeSession != null && !activeSession.isExpired();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Icon(
                    Icons.share_location,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Location Sharing',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Recipient transparency card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.isGroup ? Icons.group : Icons.person,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.isGroup
                                ? 'Sharing with group: ${widget.targetName} (${widget.memberCount ?? 0} members)'
                                : 'Sharing with: ${widget.targetName}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🔒 End-to-end encrypted pairwise. Offline mesh routing only.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Content based on permission state
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_permissionStatus ==
                  LocationPermissionStatus.serviceDisabled) ...[
                _buildWarningCard(
                  icon: Icons.location_disabled,
                  title: 'Location Services Disabled',
                  message:
                      'Device GPS or location services are turned off. Please turn on location services on your device to share location.',
                  buttonText: 'Check Again',
                  onButtonPressed: _checkPermission,
                ),
              ] else if (_permissionStatus ==
                  LocationPermissionStatus.deniedForever) ...[
                _buildWarningCard(
                  icon: Icons.block,
                  title: 'Permission Permanently Denied',
                  message:
                      'Location permission was denied. Please open system App Settings to grant Offlink location access.',
                  buttonText: 'Check Again',
                  onButtonPressed: _checkPermission,
                ),
              ] else if (_permissionStatus ==
                  LocationPermissionStatus.denied) ...[
                _buildWarningCard(
                  icon: Icons.near_me_disabled,
                  title: 'Location Permission Needed',
                  message:
                      'Offlink needs permission to access your device coordinates to share them directly with your contacts over BLE mesh.',
                  buttonText: 'Grant Permission',
                  onButtonPressed: _requestPermission,
                ),
              ] else ...[
                // Permission granted: Show Live active state or sharing options
                if (isLiveActive) ...[
                  _buildActiveLiveSharingCard(activeSession),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text(
                      'Stop Live Sharing',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _stopLiveSharing,
                  ),
                ] else ...[
                  // Option 1: One-time Snapshot
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.my_location,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: const Text(
                      'Share Current Location',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Send a one-time coordinate snapshot. Does not track your movement.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _shareSnapshot,
                      child: const Text('Send'),
                    ),
                  ),

                  const Divider(height: 28),

                  // Option 2: Live Location
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.share_location,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Live Location',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Updates every 30s until expiration. You can stop anytime.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Duration selection
                  const Text(
                    'Sharing Duration:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<Duration>(
                    segments: const [
                      ButtonSegment(
                        value: Duration(minutes: 15),
                        label: Text('15 min'),
                      ),
                      ButtonSegment(
                        value: Duration(minutes: 30),
                        label: Text('30 min'),
                      ),
                      ButtonSegment(
                        value: Duration(minutes: 60),
                        label: Text('1 hour'),
                      ),
                    ],
                    selected: {_selectedDuration},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _selectedDuration = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      'Start Live Sharing (${_selectedDuration.inMinutes}m)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _startLiveSharing,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onButtonPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLiveSharingCard(LiveLocationSession session) {
    final theme = Theme.of(context);
    final remainingMinutes = session.remainingTime().inMinutes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Location is Active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining duration: ~$remainingMinutes minutes (updates every 30s)',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (session.lastPosition != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last sent: ${session.lastPosition!.latitude.toStringAsFixed(4)}°, ${session.lastPosition!.longitude.toStringAsFixed(4)}°',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}
