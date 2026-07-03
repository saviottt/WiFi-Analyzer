import 'package:flutter/material.dart';
import '../models/wifi_network.dart';

/// Returns the color associated with a [SignalQuality] bucket.
Color signalQualityColor(SignalQuality quality) {
  switch (quality) {
    case SignalQuality.excellent:
      return const Color(0xFF00E676); // Green
    case SignalQuality.good:
      return const Color(0xFF76FF03); // Light green
    case SignalQuality.fair:
      return const Color(0xFFFFC107); // Amber
    case SignalQuality.weak:
      return const Color(0xFFFF5252); // Red
  }
}

/// Human readable label for a [SignalQuality] bucket.
String signalQualityLabel(SignalQuality quality) {
  switch (quality) {
    case SignalQuality.excellent:
      return 'Excellent';
    case SignalQuality.good:
      return 'Good';
    case SignalQuality.fair:
      return 'Fair';
    case SignalQuality.weak:
      return 'Weak';
  }
}

/// A compact bar-style signal strength indicator, similar to a phone's
/// WiFi icon, colored according to signal quality.
class SignalIndicator extends StatelessWidget {
  final int rssi;
  final double size;

  const SignalIndicator({super.key, required this.rssi, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final quality = _qualityFor(rssi);
    final color = signalQualityColor(quality);
    final activeBars = _activeBarsFor(quality);

    return SizedBox(
      width: size,
      height: size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isActive = index < activeBars;
          final barHeight = size * ((index + 1) / 4);
          return Container(
            width: size / 6,
            height: barHeight,
            margin: EdgeInsets.symmetric(horizontal: size * 0.03),
            decoration: BoxDecoration(
              color: isActive ? color : color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  SignalQuality _qualityFor(int rssi) {
    if (rssi >= -50) return SignalQuality.excellent;
    if (rssi >= -60) return SignalQuality.good;
    if (rssi >= -70) return SignalQuality.fair;
    return SignalQuality.weak;
  }

  int _activeBarsFor(SignalQuality quality) {
    switch (quality) {
      case SignalQuality.excellent:
        return 4;
      case SignalQuality.good:
        return 3;
      case SignalQuality.fair:
        return 2;
      case SignalQuality.weak:
        return 1;
    }
  }
}
