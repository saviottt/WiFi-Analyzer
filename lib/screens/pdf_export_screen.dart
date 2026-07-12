import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../utils/file_utils.dart';
import '../models/wifi_network.dart';
import '../models/wifi_metadata.dart';
import '../providers/wifi_provider.dart';
import '../services/pdf_service.dart';
import '../widgets/signal_indicator.dart';

/// Screen allowing the user to review selected access points, edit/input
/// floor names and locations, and export the final report as a PDF.
class PdfExportScreen extends StatefulWidget {
  final List<WifiNetwork> selectedNetworks;

  const PdfExportScreen({super.key, required this.selectedNetworks});

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  final Map<String, TextEditingController> _floorControllers = {};
  final Map<String, TextEditingController> _locationControllers = {};
  bool _isGenerating = false;
  String _generatingMessage = 'Generating PDF...';

  @override
  void initState() {
    super.initState();
    final provider = context.read<WifiProvider>();
    for (final net in widget.selectedNetworks) {
      final meta = provider.getMetadata(net.bssid);
      _floorControllers[net.bssid] = TextEditingController(text: meta?.floorName ?? '');
      _locationControllers[net.bssid] = TextEditingController(text: meta?.location ?? '');
    }
  }

  @override
  void dispose() {
    for (final controller in _floorControllers.values) {
      controller.dispose();
    }
    for (final controller in _locationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generateAndShareReport() async {
    setState(() {
      _generatingMessage = 'Generating PDF...';
      _isGenerating = true;
    });

    try {
      final provider = context.read<WifiProvider>();
      final Map<String, WifiCustomMetadata> localMetadataMap = {};

      // 1. Save all details back to the provider (persisting them locally)
      for (final net in widget.selectedNetworks) {
        final floorText = _floorControllers[net.bssid]!.text.trim();
        final locationText = _locationControllers[net.bssid]!.text.trim();

        await provider.saveMetadata(net.bssid, floorText, locationText);
        localMetadataMap[net.bssid] = WifiCustomMetadata(
          floorName: floorText,
          location: locationText,
        );
      }

      // 2. Generate PDF bytes
      final pdfBytes = await PdfService.generateWifiReport(
        networks: widget.selectedNetworks,
        metadataMap: localMetadataMap,
      );

      // 3. Write PDF to temporary storage
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/wifi_audit_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      // 4. Download PDF with share fallback
      if (mounted) {
        await FileUtils.downloadFile(
          context: context,
          tempFile: file,
          shareText: 'WiFi Analyzer Site Survey Report',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _generateAndShareJson() async {
    setState(() {
      _generatingMessage = 'Generating JSON...';
      _isGenerating = true;
    });

    try {
      final provider = context.read<WifiProvider>();
      final List<Map<String, dynamic>> exportData = [];

      // 1. Save all details back to the provider (persisting them locally)
      for (final net in widget.selectedNetworks) {
        final floorText = _floorControllers[net.bssid]!.text.trim();
        final locationText = _locationControllers[net.bssid]!.text.trim();

        await provider.saveMetadata(net.bssid, floorText, locationText);
        
        exportData.add({
          'ssid': net.ssid,
          'bssid': net.bssid,
          'rssi': net.rssi,
          'signalPercentage': net.signalPercentage,
          'frequency': net.frequency,
          'channel': net.channel,
          'band': net.bandLabel,
          'security': net.securityLabel,
          'estimatedDistance': net.hasValidDistance ? net.distanceEstimate : null,
          'floorName': floorText,
          'location': locationText,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // 2. Generate JSON string (pretty print)
      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(exportData);

      // 3. Write JSON to temporary storage
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/wifi_audit_report_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      // 4. Download JSON with share fallback
      if (mounted) {
        await FileUtils.downloadFile(
          context: context,
          tempFile: file,
          shareText: 'WiFi Analyzer Site Survey JSON Report',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate JSON: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Details'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header Summary Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_rounded, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected Access Points: ${widget.selectedNetworks.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enter Floor and Location details below before exporting.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Selected AP Editor List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: widget.selectedNetworks.length,
                  itemBuilder: (context, index) {
                    final network = widget.selectedNetworks[index];
                    final signalColor = signalQualityColor(network.signalQuality);

                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHigh,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // AP Header Info
                            Row(
                              children: [
                                SignalIndicator(rssi: network.rssi, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    network.ssid,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: signalColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${network.rssi} dBm',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: signalColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'BSSID: ${network.bssid}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Mini form for Floor ID and Location
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _floorControllers[network.bssid],
                                    decoration: InputDecoration(
                                      labelText: 'Floor Name/ID',
                                      hintText: 'e.g. 2nd Floor',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      prefixIcon: const Icon(Icons.layers_outlined, size: 18),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _locationControllers[network.bssid],
                                    decoration: InputDecoration(
                                      labelText: 'AP Location',
                                      hintText: 'e.g. Lobby, Server Room',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Generating Overlay
          if (_isGenerating)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _generatingMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _generateAndShareJson,
                  icon: const Icon(Icons.code_rounded),
                  label: const Text('Download JSON'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateAndShareReport,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Download PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
