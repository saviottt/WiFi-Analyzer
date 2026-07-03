import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/wifi_network.dart';

/// Handles exporting the current scan results to a CSV file saved on
/// local device storage.
class CsvExporter {
  CsvExporter._();

  /// Writes [networks] to a timestamped CSV file inside the app's
  /// documents directory and returns the resulting [File].
  ///
  /// Columns: SSID, BSSID, RSSI, Frequency, Channel, Band, Security, Timestamp
  static Future<File> exportToCsv(List<WifiNetwork> networks) async {
    final List<List<dynamic>> rows = [
      ['SSID', 'BSSID', 'RSSI', 'Frequency', 'Channel', 'Band', 'Security', 'Timestamp'],
    ];

    for (final network in networks) {
      rows.add([
        network.ssid,
        network.bssid,
        network.rssi,
        network.frequency,
        network.channel,
        network.bandLabel,
        network.securityLabel,
        network.timestamp.toIso8601String(),
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);

    final directory = await _resolveExportDirectory();
    final fileName =
        'wifi_scan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    return file.writeAsString(csvString);
  }

  /// Resolves the best available directory to store exported files.
  /// Falls back to the application documents directory if external
  /// storage is unavailable (e.g. on iOS or restricted Android setups).
  static Future<Directory> _resolveExportDirectory() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return extDir;
    } catch (_) {
      // Fall through to documents directory.
    }
    return getApplicationDocumentsDirectory();
  }
}
