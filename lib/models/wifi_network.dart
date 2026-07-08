import 'package:wifi_scan/wifi_scan.dart';
import '../utils/wifi_utils.dart';

/// WiFi frequency band classification.
enum WifiBand { ghz24, ghz5, ghz6, unknown }

/// Security protocol detected from the AP capabilities string.
enum SecurityType { open, wep, wpa, wpa2, wpa3, wpa2wpa3, unknown }

/// Bucketed signal quality used for coloring and UI badges.
enum SignalQuality { excellent, good, fair, weak }

/// Immutable representation of a single scanned WiFi access point,
/// enriched with derived fields (channel, band, security, distance...).
class WifiNetwork {
  final String ssid;
  final String bssid;
  final int rssi; // dBm, negative value (e.g. -45)
  final int frequency; // MHz
  final String capabilities; // raw capabilities string e.g. [WPA2-PSK-CCMP][ESS]
  final bool isConnected;
  final DateTime timestamp;

  const WifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.capabilities,
    required this.isConnected,
    required this.timestamp,
  });

  /// Builds a [WifiNetwork] from a raw [WiFiAccessPoint] result returned by
  /// the wifi_scan plugin.
  factory WifiNetwork.fromAccessPoint(
    WiFiAccessPoint ap, {
    required bool isConnected,
  }) {
    return WifiNetwork(
      ssid: ap.ssid.isEmpty ? '(Hidden Network)' : ap.ssid,
      bssid: ap.bssid,
      rssi: ap.level,
      frequency: ap.frequency,
      capabilities: ap.capabilities,
      isConnected: isConnected,
      timestamp: DateTime.now(),
    );
  }

  /// WiFi channel number derived from [frequency].
  int get channel => WifiUtils.frequencyToChannel(frequency);

  /// Frequency band (2.4GHz / 5GHz / 6GHz).
  WifiBand get band => WifiUtils.frequencyToBand(frequency);

  /// Human readable band label, e.g. "2.4 GHz".
  String get bandLabel => WifiUtils.bandLabel(band);

  /// Parsed security type from the raw capabilities string.
  SecurityType get securityType => WifiUtils.parseSecurity(capabilities);

  /// Human readable security label, e.g. "WPA2".
  String get securityLabel => WifiUtils.securityLabel(securityType);

  /// Bucketed signal quality derived from RSSI.
  SignalQuality get signalQuality => WifiUtils.signalQuality(rssi);

  /// Signal strength expressed as a 0-100 percentage.
  int get signalPercentage => WifiUtils.signalPercentage(rssi);

  /// Approximate distance from the access point, in meters.
  double get distanceEstimate => WifiUtils.estimateDistance(rssi, frequency);

  /// Whether the distance estimate is valid (non-negative).
  bool get hasValidDistance => distanceEstimate >= 0;

  /// Unique identity key combining SSID + BSSID, used for history tracking.
  String get key => '$ssid|$bssid';

  WifiNetwork copyWith({
    String? ssid,
    String? bssid,
    int? rssi,
    int? frequency,
    String? capabilities,
    bool? isConnected,
    DateTime? timestamp,
  }) {
    return WifiNetwork(
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      rssi: rssi ?? this.rssi,
      frequency: frequency ?? this.frequency,
      capabilities: capabilities ?? this.capabilities,
      isConnected: isConnected ?? this.isConnected,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
