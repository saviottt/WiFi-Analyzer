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
  locationDisabled,
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

  bool _lastScanThrottled = false;
  bool get lastScanThrottled => _lastScanThrottled;

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
    if (location.isPermanentlyDenied) return true;

    if (await _needsNearbyWifiDevicesPermission()) {
      final nearby = await Permission.nearbyWifiDevices.status;
      return nearby.isPermanentlyDenied;
    }

    return false;
  }

  /// Triggers a new WiFi scan and returns the normalized results.
  /// Throws a [WifiServiceError] (as an exception) describing failures.
  Future<List<WifiNetwork>> scan() async {
    try {
      final canStart = await WiFiScan.instance.canStartScan(askPermissions: false);
      if (canStart == CanStartScan.notSupported) {
        throw WifiServiceError.scanNotSupported;
      }
      if (canStart == CanStartScan.noLocationPermissionRequired ||
          canStart == CanStartScan.noLocationPermissionDenied ||
          canStart == CanStartScan.noLocationPermissionUpgradeAccuracy) {
        throw WifiServiceError.permissionDenied;
      }
      if (canStart == CanStartScan.noLocationServiceDisabled) {
        throw WifiServiceError.locationDisabled;
      }
    } catch (e) {
      if (e is WifiServiceError) rethrow;
      throw WifiServiceError.unknown;
    }

    // Kick off a scan; check return value to detect system throttling.
    bool success = false;
    try {
      success = await WiFiScan.instance.startScan();
      _lastScanThrottled = !success;
    } catch (_) {
      _lastScanThrottled = true;
    }

    try {
      final canGet = await WiFiScan.instance.canGetScannedResults(askPermissions: false);
      if (canGet == CanGetScannedResults.notSupported) {
        throw WifiServiceError.scanNotSupported;
      }
      if (canGet == CanGetScannedResults.noLocationPermissionRequired ||
          canGet == CanGetScannedResults.noLocationPermissionDenied ||
          canGet == CanGetScannedResults.noLocationPermissionUpgradeAccuracy) {
        throw WifiServiceError.permissionDenied;
      }
      if (canGet == CanGetScannedResults.noLocationServiceDisabled) {
        throw WifiServiceError.locationDisabled;
      }
    } catch (e) {
      if (e is WifiServiceError) rethrow;
      throw WifiServiceError.unknown;
    }

    try {
      List<WiFiAccessPoint> results = [];
      if (success) {
        final completer = Completer<List<WiFiAccessPoint>>();
        StreamSubscription<List<WiFiAccessPoint>>? subscription;
        Timer? timeoutTimer;

        subscription = WiFiScan.instance.onScannedResultsAvailable.listen(
          (newResults) {
            if (!completer.isCompleted) {
              timeoutTimer?.cancel();
              subscription?.cancel();
              completer.complete(newResults);
            }
          },
          onError: (err) {
            if (!completer.isCompleted) {
              timeoutTimer?.cancel();
              subscription?.cancel();
              completer.completeError(err);
            }
          },
        );

        // Safety timeout to fallback to cached results in case OS doesn't fire the stream
        timeoutTimer = Timer(const Duration(seconds: 4), () async {
          if (!completer.isCompleted) {
            subscription?.cancel();
            try {
              final cachedResults = await WiFiScan.instance.getScannedResults();
              completer.complete(cachedResults);
            } catch (e) {
              completer.complete([]);
            }
          }
        });

        results = await completer.future;
      } else {
        // Scan throttled, fallback immediately to cached results
        results = await WiFiScan.instance.getScannedResults();
      }

      final connectedBssid = await getConnectedBssid();

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
    } catch (_) {
      throw WifiServiceError.unknown;
    }
  }

  /// Returns the BSSID of the currently connected WiFi network, if any.
  Future<String?> getConnectedBssid() async {
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
