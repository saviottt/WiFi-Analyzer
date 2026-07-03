import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wifi_network.dart';
import '../providers/wifi_provider.dart';
import '../widgets/signal_indicator.dart';
import 'rssi_graph_screen.dart';

/// Full-detail view for a single access point, reached via Hero
/// transition from the [NetworkCard] on the home screen.
class NetworkDetailsScreen extends StatelessWidget {
  final WifiNetwork network;

  const NetworkDetailsScreen({super.key, required this.network});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Network Details')),
      body: Consumer<WifiProvider>(
        builder: (context, provider, _) {
          // Find the latest network data from the provider to ensure live updates.
          final latestNetwork = provider.allNetworks.firstWhere(
            (n) => n.key == network.key,
            orElse: () => network,
          );

          final color = signalQualityColor(latestNetwork.signalQuality);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    Hero(
                      tag: 'signal_${latestNetwork.bssid}',
                      child: SignalIndicator(rssi: latestNetwork.rssi, size: 64),
                    ),
                    const SizedBox(height: 12),
                    Hero(
                      tag: 'ssid_${latestNetwork.bssid}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          latestNetwork.ssid,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signalQualityLabel(latestNetwork.signalQuality),
                      style: theme.textTheme.titleMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _DetailRow(label: 'SSID', value: latestNetwork.ssid),
                      _DetailRow(label: 'MAC Address (BSSID)', value: latestNetwork.bssid),
                      _DetailRow(label: 'RSSI', value: '${latestNetwork.rssi} dBm'),
                      _DetailRow(
                        label: 'Signal Quality',
                        value: signalQualityLabel(latestNetwork.signalQuality),
                        valueColor: color,
                      ),
                      _DetailRow(
                        label: 'Signal Percentage',
                        value: '${latestNetwork.signalPercentage}%',
                      ),
                      _DetailRow(
                        label: 'Frequency',
                        value: '${latestNetwork.frequency} MHz',
                      ),
                      _DetailRow(label: 'Channel', value: '${latestNetwork.channel}'),
                      _DetailRow(label: 'Band', value: latestNetwork.bandLabel),
                      _DetailRow(label: 'Security', value: latestNetwork.securityLabel),
                      _DetailRow(
                        label: 'Capabilities',
                        value: latestNetwork.capabilities.isEmpty
                            ? 'N/A'
                            : latestNetwork.capabilities,
                      ),
                      _DetailRow(
                        label: 'Estimated Distance',
                        value: '${latestNetwork.distanceEstimate.toStringAsFixed(2)} m',
                      ),
                      _DetailRow(
                        label: 'Status',
                        value: latestNetwork.isConnected ? 'Connected' : 'Not Connected',
                        valueColor: latestNetwork.isConnected
                            ? theme.colorScheme.primary
                            : null,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RssiGraphScreen(network: latestNetwork),
                    ),
                  );
                },
                icon: const Icon(Icons.show_chart_rounded),
                label: const Text('View Live RSSI Graph'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
