import 'dart:math';
import '../models/wifi_network.dart';

/// Pure, static helper functions used to derive WiFi metadata from raw
/// scan results (frequency -> channel, RSSI -> distance, etc).
class WifiUtils {
  WifiUtils._();

  /// Converts a frequency in MHz into its corresponding WiFi channel number.
  /// Supports 2.4GHz, 5GHz and 6GHz (WiFi 6E) bands.
  /// Returns -1 if the frequency is out of any known WiFi range.
  static int frequencyToChannel(int frequencyMHz) {
    // 2.4 GHz band
    if (frequencyMHz == 2484) return 14;
    if (frequencyMHz >= 2412 && frequencyMHz <= 2472) {
      return ((frequencyMHz - 2412) ~/ 5) + 1;
    }
    // 5 GHz band
    if (frequencyMHz >= 5170 && frequencyMHz <= 5895) {
      return ((frequencyMHz - 5000) ~/ 5);
    }
    // 6 GHz band (WiFi 6E / 7)
    if (frequencyMHz >= 5955 && frequencyMHz <= 7115) {
      return ((frequencyMHz - 5950) ~/ 5);
    }
    return -1;
  }

  /// Classifies a frequency (MHz) into a [WifiBand].
  static WifiBand frequencyToBand(int frequencyMHz) {
    if (frequencyMHz >= 2400 && frequencyMHz < 2500) return WifiBand.ghz24;
    if (frequencyMHz >= 4900 && frequencyMHz < 5900) return WifiBand.ghz5;
    if (frequencyMHz >= 5900 && frequencyMHz <= 7115) return WifiBand.ghz6;
    return WifiBand.unknown;
  }

  /// Human readable label for a [WifiBand].
  static String bandLabel(WifiBand band) {
    switch (band) {
      case WifiBand.ghz24:
        return '2.4 GHz';
      case WifiBand.ghz5:
        return '5 GHz';
      case WifiBand.ghz6:
        return '6 GHz';
      case WifiBand.unknown:
        return 'Unknown';
    }
  }

  /// Parses the raw capabilities string (e.g. "[WPA2-PSK-CCMP][ESS]")
  /// returned by the platform scanner into a [SecurityType].
  static SecurityType parseSecurity(String capabilities) {
    final cap = capabilities.toUpperCase();
    final hasWpa3 = cap.contains('WPA3') || cap.contains('SAE');
    final hasWpa2 = cap.contains('WPA2') || cap.contains('RSN');
    final hasWpa = cap.contains('WPA') && !hasWpa2 && !hasWpa3;
    final hasWep = cap.contains('WEP');

    if (hasWpa3 && hasWpa2) return SecurityType.wpa2wpa3;
    if (hasWpa3) return SecurityType.wpa3;
    if (hasWpa2) return SecurityType.wpa2;
    if (hasWpa) return SecurityType.wpa;
    if (hasWep) return SecurityType.wep;
    if (cap.isEmpty || !cap.contains(RegExp(r'WPA|WEP|RSN|SAE'))) {
      return SecurityType.open;
    }
    return SecurityType.unknown;
  }

  /// Human readable label for a [SecurityType].
  static String securityLabel(SecurityType type) {
    switch (type) {
      case SecurityType.open:
        return 'Open';
      case SecurityType.wep:
        return 'WEP';
      case SecurityType.wpa:
        return 'WPA';
      case SecurityType.wpa2:
        return 'WPA2';
      case SecurityType.wpa3:
        return 'WPA3';
      case SecurityType.wpa2wpa3:
        return 'WPA2/WPA3';
      case SecurityType.unknown:
        return 'Unknown';
    }
  }

  /// Buckets an RSSI value (dBm) into a [SignalQuality] category.
  /// Thresholds follow common industry conventions:
  /// >= -50 dBm: excellent, >= -60: good, >= -70: fair, else weak.
  static SignalQuality signalQuality(int rssi) {
    if (rssi >= -50) return SignalQuality.excellent;
    if (rssi >= -60) return SignalQuality.good;
    if (rssi >= -70) return SignalQuality.fair;
    return SignalQuality.weak;
  }

  /// Converts RSSI (dBm) into an approximate 0-100 signal percentage.
  static int signalPercentage(int rssi) {
    final pct = 2 * (rssi + 100);
    return pct.clamp(0, 100);
  }

  /// Estimates distance (in meters) from an access point using the
  /// free-space log-distance path loss model:
  ///   distance = 10 ^ ((27.55 - 20*log10(freqMHz) + |RSSI|) / 20)
  /// This is an approximation only; real-world distance depends heavily
  /// on obstacles, antenna orientation and transmit power.
  static double estimateDistance(int rssi, int frequencyMHz) {
    if (frequencyMHz <= 0) return -1;
    final exponent =
        (27.55 - (20 * _log10(frequencyMHz.toDouble())) + rssi.abs()) / 20.0;
    final distance = pow(10, exponent).toDouble();
    return double.parse(distance.toStringAsFixed(2));
  }

  static double _log10(double x) => log(x) / ln10;
}
