import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/wifi_network.dart';
import '../models/wifi_metadata.dart';
import '../providers/wifi_provider.dart';

/// Handles exporting the scan results and metadata to a JSON file saved on
/// local device storage.
class JsonExporter {
  JsonExporter._();

  /// Writes [networks] along with their custom metadata to a timestamped JSON file
  /// inside the app's temporary directory and returns the resulting [File].
  static Future<File> exportToJson(List<WifiNetwork> networks, WifiProvider provider) async {
    final List<Map<String, dynamic>> exportData = [];

    for (final net in networks) {
      final meta = provider.getMetadata(net.bssid);
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
        'floorName': meta?.floorName ?? '',
        'location': meta?.location ?? '',
        'timestamp': net.timestamp.toIso8601String(),
      });
    }

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(exportData);

    final directory = await getTemporaryDirectory();
    final fileName =
        'wifi_scan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final file = File('${directory.path}/$fileName');
    return file.writeAsString(jsonString);
  }

  /// Writes details of a single [network] and its [metadata] to a timestamped JSON file
  /// inside the temporary directory and returns the resulting [File].
  static Future<File> exportSingleToJson(WifiNetwork network, WifiCustomMetadata? metadata) async {
    final Map<String, dynamic> exportData = {
      'ssid': network.ssid,
      'bssid': network.bssid,
      'rssi': network.rssi,
      'signalPercentage': network.signalPercentage,
      'frequency': network.frequency,
      'channel': network.channel,
      'band': network.bandLabel,
      'security': network.securityLabel,
      'estimatedDistance': network.hasValidDistance ? network.distanceEstimate : null,
      'floorName': metadata?.floorName ?? '',
      'location': metadata?.location ?? '',
      'timestamp': network.timestamp.toIso8601String(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(exportData);

    final directory = await getTemporaryDirectory();
    final cleanSsid = network.ssid.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final fileName =
        'wifi_details_${cleanSsid}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final file = File('${directory.path}/$fileName');
    return file.writeAsString(jsonString);
  }
}
