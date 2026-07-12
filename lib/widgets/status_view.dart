import 'package:flutter/material.dart';
import '../providers/wifi_provider.dart';

/// Presents a friendly full-screen message for a given [AppErrorState],
/// with an optional action button (e.g. "Grant Permission", "Open Settings").
class StatusView extends StatelessWidget {
  final AppErrorState state;
  final VoidCallback? onPrimaryAction;

  const StatusView({super.key, required this.state, this.onPrimaryAction});

  _StatusContent get _content {
    switch (state) {
      case AppErrorState.permissionDenied:
        return _StatusContent(
          icon: Icons.location_off_rounded,
          title: 'Permission Required',
          message:
              'WiFi Analyzer needs Location and Nearby Devices permissions '
              'to discover nearby networks. Please grant access to continue.',
          actionLabel: 'Grant Permission',
        );
      case AppErrorState.permissionPermanentlyDenied:
        return _StatusContent(
          icon: Icons.settings_rounded,
          title: 'Permission Blocked',
          message:
              'Permissions were permanently denied. Please enable Location '
              'access for WiFi Analyzer in system settings.',
          actionLabel: 'Open Settings',
        );
      case AppErrorState.wifiDisabled:
        return _StatusContent(
          icon: Icons.wifi_off_rounded,
          title: 'WiFi is Disabled',
          message: 'Please turn on WiFi to scan for nearby networks.',
          actionLabel: 'Retry',
        );
      case AppErrorState.locationDisabled:
        return _StatusContent(
          icon: Icons.location_off_rounded,
          title: 'Location Services Disabled',
          message:
              'WiFi Analyzer needs Location Services (GPS) to be enabled on your device '
              'to scan for nearby networks.',
          actionLabel: 'Retry',
        );
      case AppErrorState.scanNotSupported:
        return _StatusContent(
          icon: Icons.error_outline_rounded,
          title: 'Unsupported Device',
          message:
              'This device does not support WiFi scanning through the '
              'Android platform APIs.',
          actionLabel: null,
        );
      case AppErrorState.noNetworksFound:
        return _StatusContent(
          icon: Icons.wifi_find_rounded,
          title: 'No Networks Found',
          message:
              'No nearby WiFi networks were detected. Pull down to refresh '
              'or move to a different location.',
          actionLabel: 'Scan Again',
        );
      case AppErrorState.unknown:
        return _StatusContent(
          icon: Icons.warning_amber_rounded,
          title: 'Something Went Wrong',
          message: 'An unexpected error occurred while scanning for networks.',
          actionLabel: 'Retry',
        );
      case AppErrorState.none:
        return const _StatusContent(
          icon: Icons.check_circle_outline_rounded,
          title: 'All Good',
          message: '',
          actionLabel: null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _content;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(content.icon, size: 72, color: theme.colorScheme.outline),
            const SizedBox(height: 20),
            Text(
              content.title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              content.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (content.actionLabel != null && onPrimaryAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onPrimaryAction,
                child: Text(content.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusContent {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;

  const _StatusContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
  });
}
