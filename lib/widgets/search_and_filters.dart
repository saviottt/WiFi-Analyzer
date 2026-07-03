import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wifi_provider.dart';

/// Search field bound to [WifiProvider.updateSearchQuery], matching by
/// SSID or MAC address (BSSID).
class NetworkSearchBar extends StatelessWidget {
  const NetworkSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SearchBar(
        hintText: 'Search by SSID or MAC address...',
        leading: const Icon(Icons.search_rounded),
        elevation: const WidgetStatePropertyAll(0),
        onChanged: (value) =>
            context.read<WifiProvider>().updateSearchQuery(value),
      ),
    );
  }
}

/// Horizontally scrollable row of filter chips (band + security type).
class NetworkFilterChips extends StatelessWidget {
  const NetworkFilterChips({super.key});

  static const _labels = {
    NetworkFilter.band24: '2.4 GHz',
    NetworkFilter.band5: '5 GHz',
    NetworkFilter.open: 'Open',
    NetworkFilter.wpa: 'WPA',
    NetworkFilter.wpa2: 'WPA2',
    NetworkFilter.wpa3: 'WPA3',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WifiProvider>();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: NetworkFilter.values.map((filter) {
          final isSelected = provider.activeFilters.contains(filter);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_labels[filter]!),
              selected: isSelected,
              onSelected: (_) =>
                  context.read<WifiProvider>().toggleFilter(filter),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}
