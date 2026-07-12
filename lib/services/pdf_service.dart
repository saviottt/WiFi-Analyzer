import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/wifi_network.dart';
import '../models/wifi_metadata.dart';

/// Service for generating professional WiFi audit reports in PDF format.
class PdfService {
  static Future<Uint8List> generateWifiReport({
    required List<WifiNetwork> networks,
    required Map<String, WifiCustomMetadata> metadataMap,
  }) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final generationTime = dateFormat.format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              'WiFi Analyzer Audit Report',
              style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Title Header Block
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'WiFi Site Survey & Audit',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Detailed access point signal and location analysis.',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        generationTime,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Info Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryCard('Total APs Audited', '${networks.length}'),
                _buildSummaryCard(
                  'Strongest SSID',
                  networks.isNotEmpty ? _findStrongestSSID(networks) : 'N/A',
                ),
                _buildSummaryCard(
                  'Average Signal',
                  networks.isNotEmpty ? '${_calculateAverageRssi(networks)} dBm' : 'N/A',
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Access Points Table Header
            pw.Text(
              'Audited Access Points',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 8),

            // Access Points Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(2.5),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.8),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(2.0),
                6: pw.FlexColumnWidth(3.0),
              },
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    'SSID',
                    'MAC (BSSID)',
                    'Signal',
                    'Freq / Ch',
                    'Security',
                    'Floor Name/ID',
                    'AP Location',
                  ].map((title) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          fontSize: 8.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Data rows
                ...networks.map((network) {
                  final metadata = metadataMap[network.bssid];
                  final floor = metadata?.floorName.isNotEmpty == true ? metadata!.floorName : 'N/A';
                  final loc = metadata?.location.isNotEmpty == true ? metadata!.location : 'N/A';

                  return pw.TableRow(
                    children: [
                      network.ssid,
                      network.bssid,
                      '${network.rssi} dBm\n(${network.signalPercentage}%)',
                      '${network.frequency} MHz\nCh ${network.channel}',
                      network.securityLabel,
                      floor,
                      loc,
                    ].map((cellValue) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          cellValue,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryCard(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ],
      ),
    );
  }

  static String _findStrongestSSID(List<WifiNetwork> networks) {
    if (networks.isEmpty) return 'N/A';
    WifiNetwork strongest = networks[0];
    for (final net in networks) {
      if (net.rssi > strongest.rssi) {
        strongest = net;
      }
    }
    return strongest.ssid;
  }

  static int _calculateAverageRssi(List<WifiNetwork> networks) {
    if (networks.isEmpty) return 0;
    int sum = 0;
    for (final net in networks) {
      sum += net.rssi;
    }
    return (sum / networks.length).round();
  }
}
