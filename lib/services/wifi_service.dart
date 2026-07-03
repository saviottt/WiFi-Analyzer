import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/wifi_network.dart';

/// Result wrapper describing why a scan could not be performed, if at all.
enum WifiServiceError {
  none,
  permissionDenied,
  wifiDisabled,
  scanNotSupported,
  unknown,
}

/// Thin service layer around the wifi_scan and network_info_plus plugins.
/// Responsible for permission handling, triggering scans and normalizing
/// raw platform results into [WifiNetwork] domain objects.
class WifiService {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<bool> _needsNearbyWifiDevicesPermission() async {
    if (!Platform.isAndroid) return false;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return androidInfo.version.sdkInt >= 33;
  }

  /// Requests all permissions required for WiFi scanning:
  /// Location (required by Android for SSID visibility) and, on
  /// Android 13+, Nearby WiFi Devices.
  Future<bool> requestPermissions() async {
    final statuses = <Permission, PermissionStatus>{};

    statuses[Permission.locationWhenInUse] =
        await Permission.locationWhenInUse.request();

    if (await _needsNearbyWifiDevicesPermission()) {
      statuses[Permission.nearbyWifiDevices] =
          await Permission.nearbyWifiDevices.request();
    }

    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  /// Checks whether required permissions are currently granted without
  /// prompting the user.
  Future<bool> hasPermissions() async {
    final location = await Permission.locationWhenInUse.status;
    final locationOk = location.isGranted || location.isLimited;

    if (await _needsNearbyWifiDevicesPermission()) {
      final nearby = await Permission.nearbyWifiDevices.status;
      final nearbyOk = nearby.isGranted || nearby.isLimited;
      return locationOk && nearbyOk;
    }

    return locationOk;
  }

  /// Returns true if permissions were permanently denied and the app
  /// should direct the user to system settings.
  Future<bool> isPermanentlyDenied() async {
    final location = await Permission.locationWhenInUse.status;
    return location.isPermanentlyDenied;
  }

  /// Triggers a new WiFi scan and returns the normalized results.
  /// Throws a [WifiServiceError] (as an exception) describing failures.
  Future<List<WifiNetwork>> scan() async {
    final canStart = await WiFiScan.instance.canStartScan();
    if (canStart == CanStartScan.notSupported) {
      throw WifiServiceError.scanNotSupported;
    }
    if (canStart == CanStartScan.noLocationPermissionRequired ||
        canStart == CanStartScan.noLocationPermissionDenied ||
        canStart == CanStartScan.noLocationPermissionUpgradeAccuracy) {
      throw WifiServiceError.permissionDenied;
    }
    if (canStart == CanStartScan.noLocationServiceDisabled) {
      throw WifiServiceError.wifiDisabled;
    }

    // Kick off a scan; ignore return value, we read cached results after.
    try {
      await WiFiScan.instance.startScan();
    } catch (_) {
      // Some OEMs throttle scans; we still attempt to read cached results.
    }

    final canGet = await WiFiScan.instance.canGetScannedResults();
    if (canGet == CanGetScannedResults.notSupported) {
      throw WifiServiceError.scanNotSupported;
    }
    if (canGet == CanGetScannedResults.noLocationPermissionRequired ||
        canGet == CanGetScannedResults.noLocationPermissionDenied ||
        canGet == CanGetScannedResults.noLocationPermissionUpgradeAccuracy) {
      throw WifiServiceError.permissionDenied;
    }
    if (canGet == CanGetScannedResults.noLocationServiceDisabled) {
      throw WifiServiceError.wifiDisabled;
    }

    final results = await WiFiScan.instance.getScannedResults();
    final connectedBssid = await _getConnectedBssid();

    final networks = results
        .map((ap) => WifiNetwork.fromAccessPoint(
              ap,
              isConnected: connectedBssid != null &&
                  connectedBssid.toLowerCase() == ap.bssid.toLowerCase(),
            ))
        .toList();

    // Sort by strongest signal (highest RSSI, i.e. closest to 0) first.
    networks.sort((a, b) => b.rssi.compareTo(a.rssi));
    return networks;
  }

  /// Returns the BSSID of the currently connected WiFi network, if any.
  Future<String?> _getConnectedBssid() async {
    try {
      final bssid = await _networkInfo.getWifiBSSID();
      if (bssid == null || bssid.isEmpty || bssid == '02:00:00:00:00:00') {
        return null;
      }
      return bssid;
    } catch (_) {
      return null;
    }
  }

  /// Exposes a stream of scan results for platforms that support
  /// onScannedResultsAvailable (push-based updates). Not all devices
  /// support this; the provider falls back to polling via [scan].
  Stream<List<WiFiAccessPoint>> get onScanResultsAvailable =>
      WiFiScan.instance.onScannedResultsAvailable;
}
