import 'package:flutter/material.dart';
import '../models/wifi_network.dart';
import 'signal_indicator.dart';

/// A Material 3 card summarizing a single scanned network. Tapping the
/// card triggers [onTap], typically navigating to the details/graph screen
/// via a Hero transition keyed on the network's BSSID.
class NetworkCard extends StatelessWidget {
  final WifiNetwork network;
  final VoidCallback onTap;

  const NetworkCard({super.key, required this.network, required this.onTap});

  IconData get _securityIcon {
    switch (network.securityType) {
      case SecurityType.open:
        return Icons.lock_open_rounded;
      default:
        return Icons.lock_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = signalQualityColor(network.signalQuality);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: network.isConnected
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Hero(
                tag: 'signal_${network.bssid}',
                child: SignalIndicator(rssi: network.rssi),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Hero(
                            tag: 'ssid_${network.bssid}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                network.ssid,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (network.isConnected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      network.bssid,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          icon: Icons.wifi_rounded,
                          label: network.bandLabel,
                        ),
                        _Chip(
                          icon: Icons.tag_rounded,
                          label: 'Ch ${network.channel}',
                        ),
                        _Chip(
                          icon: _securityIcon,
                          label: network.securityLabel,
                        ),
                        _Chip(
                          icon: Icons.social_distance_rounded,
                          label: network.hasValidDistance
                              ? '~${network.distanceEstimate.toStringAsFixed(1)} m'
                              : 'N/A',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${network.rssi} dBm',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    signalQualityLabel(network.signalQuality),
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
