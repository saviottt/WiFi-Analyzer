import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wifi_network.dart';
import '../providers/wifi_provider.dart';
import '../utils/wifi_utils.dart';
import '../widgets/signal_indicator.dart';

/// Displays a live-updating line chart of the last 60 RSSI readings for
/// a given network, plus average/min/max statistics.
class RssiGraphScreen extends StatelessWidget {
  final WifiNetwork network;

  const RssiGraphScreen({super.key, required this.network});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(network.ssid)),
      body: Consumer<WifiProvider>(
        builder: (context, provider, _) {
          final history = provider.historyFor(network);

          if (history.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final avg = history.reduce((a, b) => a + b) / history.length;
          final max = history.reduce((a, b) => a > b ? a : b);
          final min = history.reduce((a, b) => a < b ? a : b);
          final current = history.last;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  SignalIndicator(rssi: current, size: 36),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$current dBm',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: signalQualityColor(WifiUtils.signalQuality(current)),
                        ),
                      ),
                      Text(
                        '${history.length} of 60 readings',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AspectRatio(
                aspectRatio: 1.5,
                child: _RssiLineChart(history: history),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Average',
                      value: avg.toStringAsFixed(1),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Maximum',
                      value: '$max',
                      color: signalQualityColor(SignalQuality.excellent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Minimum',
                      value: '$min',
                      color: signalQualityColor(SignalQuality.weak),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RssiLineChart extends StatelessWidget {
  final List<int> history;

  const _RssiLineChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = <FlSpot>[
      for (int i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].toDouble()),
    ];

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: LineChart(
          duration: const Duration(milliseconds: 250),
          LineChartData(
            minY: -100,
            maxY: -20,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                strokeWidth: 1,
              ),
              drawVerticalLine: false,
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: 20,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.25,
                color: theme.colorScheme.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.primary.withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
