import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/wifi_provider.dart';
import '../utils/csv_exporter.dart';
import '../widgets/network_card.dart';
import '../widgets/search_and_filters.dart';
import '../widgets/status_view.dart';
import 'network_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshIconController;

  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Kick off permission request + initial scan after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WifiProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _refreshIconController.dispose();
    super.dispose();
  }

  Future<void> _handleManualRefresh(WifiProvider provider) async {
    _refreshIconController.repeat();
    await provider.refresh();
    _refreshIconController.stop();
    _refreshIconController.reset();
  }

  Future<void> _handlePrimaryAction(
    BuildContext context,
    WifiProvider provider,
  ) async {
    switch (provider.errorState) {
      case AppErrorState.permissionDenied:
        await provider.retryPermissions();
        break;
      case AppErrorState.permissionPermanentlyDenied:
        await openAppSettings();
        break;
      default:
        await provider.refresh();
    }
  }

  Future<void> _exportCsv(BuildContext context, WifiProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await CsvExporter.exportToCsv(provider.filteredNetworks);
      messenger.showSnackBar(
        SnackBar(content: Text('Exported to ${file.path}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WifiProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Analyzer'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: provider.filteredNetworks.isEmpty
                ? null
                : () => _exportCsv(context, provider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const NetworkSearchBar(),
            const SizedBox(height: 4),
            const NetworkFilterChips(),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(context, provider)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleManualRefresh(provider),
        child: RotationTransition(
          turns: _refreshIconController,
          child: const Icon(Icons.refresh_rounded),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WifiProvider provider) {
    if (provider.isLoading && provider.allNetworks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorState != AppErrorState.none &&
        provider.errorState != AppErrorState.noNetworksFound &&
        provider.allNetworks.isEmpty) {
      return StatusView(
        state: provider.errorState,
        onPrimaryAction: () => _handlePrimaryAction(context, provider),
      );
    }

    final networks = provider.filteredNetworks;

    if (networks.isEmpty) {
      return StatusView(
        state: AppErrorState.noNetworksFound,
        onPrimaryAction: () => provider.refresh(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 90),
        itemCount: networks.length,
        itemBuilder: (context, index) {
          final network = networks[index];
          return NetworkCard(
            network: network,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NetworkDetailsScreen(network: network),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
