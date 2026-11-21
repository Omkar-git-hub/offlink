import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/location/location_payload.dart';
import '../../domain/messaging/chat_message.dart';

/// Bubble widget rendering a privacy-preserving location snapshot or live location update.
class LocationBubble extends StatelessWidget {
  const LocationBubble({
    super.key,
    required this.message,
    required this.payload,
  });

  final ChatMessage message;
  final LocationPayload payload;

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showCoordinatesDialog(BuildContext context) {
    final coordsText =
        '${payload.latitude.toStringAsFixed(6)}, ${payload.longitude.toStringAsFixed(6)}';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              payload.isLive ? Icons.my_location : Icons.location_on,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(payload.isLive ? 'Live Location' : 'Location Snapshot'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared by: ${payload.senderDisplayName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Latitude: ${payload.latitude.toStringAsFixed(6)}°'),
            Text('Longitude: ${payload.longitude.toStringAsFixed(6)}°'),
            if (payload.accuracy != null)
              Text('Accuracy: ±${payload.accuracy!.toStringAsFixed(1)}m'),
            Text('Timestamp: ${_formatTime(payload.timestamp)} (Local)'),
            if (payload.expiresAt != null)
              Text('Expires: ${_formatTime(payload.expiresAt!)} (Local)'),
            const SizedBox(height: 12),
            const Text(
              'This location was transmitted peer-to-peer over BLE mesh without cloud or internet servers.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Coordinates'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: coordsText));
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coordinates copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutgoing = message.isOutgoing;
    final isLiveStopped = payload.sharingType == LocationSharingType.liveStop;
    final isLiveActive = payload.isLive && !isLiveStopped;

    Color cardBg;
    if (isOutgoing) {
      cardBg = theme.colorScheme.primaryContainer;
    } else {
      cardBg = theme.colorScheme.surfaceContainerHighest;
    }

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
            bottomRight: Radius.circular(isOutgoing ? 4 : 16),
          ),
          border: isLiveActive
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  width: 1.5,
                )
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCoordinatesDialog(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Icon + Type Badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLiveStopped
                          ? Icons.location_off
                          : (isLiveActive
                                ? Icons.my_location
                                : Icons.location_on),
                      size: 18,
                      color: isLiveActive
                          ? Colors.green
                          : (isOutgoing
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLiveStopped
                          ? 'Live Location (Ended)'
                          : (isLiveActive
                                ? 'Live Location'
                                : 'Location Snapshot'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOutgoing
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isLiveActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Coordinates Display
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${payload.latitude.toStringAsFixed(5)}°, ${payload.longitude.toStringAsFixed(5)}°',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (payload.accuracy != null)
                              Text(
                                'Accuracy: ±${payload.accuracy!.toStringAsFixed(0)}m',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Footer: Timestamp + Delivery icon + Tap hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tap to view / copy',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            (isOutgoing
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.7),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(payload.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                (isOutgoing
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSurfaceVariant)
                                    .withValues(alpha: 0.7),
                          ),
                        ),
                        if (isOutgoing) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.status == ChatMessageStatus.delivered
                                ? Icons.done_all
                                : (message.status == ChatMessageStatus.sent
                                      ? Icons.done
                                      : Icons.access_time),
                            size: 13,
                            color: message.status == ChatMessageStatus.delivered
                                ? Colors.blue
                                : theme.colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
