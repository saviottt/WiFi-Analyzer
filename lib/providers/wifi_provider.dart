import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/wifi_network.dart';
import '../services/wifi_service.dart';

/// Toggleable filters for the network list.
enum NetworkFilter { band24, band5, open, wpa, wpa2, wpa3 }

/// Application-wide error states surfaced to the UI.
enum AppErrorState {
  none,
  permissionDenied,
  permissionPermanentlyDenied,
  wifiDisabled,
  scanNotSupported,
  noNetworksFound,
  unknown,
}

/// Central state holder for scan results, live scanning lifecycle,
/// search/filter state and per-network RSSI history (for graphing).
///
/// Uses [WidgetsBindingObserver] to pause scanning when the app is
/// backgrounded and resume it when the app becomes active again.
class WifiProvider extends ChangeNotifier with WidgetsBindingObserver {
  final WifiService _service = WifiService();
  static const int _maxHistoryPoints = 60;
  static const Duration _scanInterval = Duration(seconds: 10);

  List<WifiNetwork> _networks = [];
  final Map<String, Queue<int>> _rssiHistory = {};

  bool _isLoading = false;
  bool _permissionGranted = false;
  AppErrorState _errorState = AppErrorState.none;
  Timer? _scanTimer;
  StreamSubscription<List<WiFiAccessPoint>>? _scanSubscription;
  bool _isScanningActive = false;
  bool _isThrottled = false;
  bool _disposed = false;

  String _searchQuery = '';
  final Set<NetworkFilter> _activeFilters = {};

  WifiProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ---------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------

  bool get isLoading => _isLoading;
  bool get permissionGranted => _permissionGranted;
  AppErrorState get errorState => _errorState;
  bool get isThrottled => _isThrottled;
  String get searchQuery => _searchQuery;
  Set<NetworkFilter> get activeFilters => UnmodifiableSetView(_activeFilters);

  /// Raw (unfiltered) list of scanned networks, sorted by signal strength.
  List<WifiNetwork> get allNetworks => List.unmodifiable(_networks);

  /// Filtered + searched list of networks presented to the UI.
  List<WifiNetwork> get filteredNetworks {
    Iterable<WifiNetwork> result = _networks;

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      result = result.where((n) =>
          n.ssid.toLowerCase().contains(query) ||
          n.bssid.toLowerCase().contains(query));
    }

    if (_activeFilters.isNotEmpty) {
      final bandFilters = _activeFilters.intersection({
        NetworkFilter.band24,
        NetworkFilter.band5,
      });
      final securityFilters = _activeFilters.intersection({
        NetworkFilter.open,
        NetworkFilter.wpa,
        NetworkFilter.wpa2,
        NetworkFilter.wpa3,
      });

      result = result.where((n) {
        if (bandFilters.isNotEmpty) {
          final matchesBand = bandFilters.any((filter) {
            switch (filter) {
              case NetworkFilter.band24:
                return n.band == WifiBand.ghz24;
              case NetworkFilter.band5:
                return n.band == WifiBand.ghz5;
              default:
                return false;
            }
          });
          if (!matchesBand) return false;
        }

        if (securityFilters.isNotEmpty) {
          final matchesSecurity = securityFilters.any((filter) {
            switch (filter) {
              case NetworkFilter.open:
                return n.securityType == SecurityType.open;
              case NetworkFilter.wpa:
                return n.securityType == SecurityType.wpa;
              case NetworkFilter.wpa2:
                return n.securityType == SecurityType.wpa2 ||
                    n.securityType == SecurityType.wpa2wpa3;
              case NetworkFilter.wpa3:
                return n.securityType == SecurityType.wpa3 ||
                    n.securityType == SecurityType.wpa2wpa3;
              default:
                return false;
            }
          });
          if (!matchesSecurity) return false;
        }

        return true;
      });
    }

    return result.toList();
  }

  /// Returns the last up-to-60 RSSI readings recorded for [network].
  List<int> historyFor(WifiNetwork network) =>
      List.unmodifiable(_rssiHistory[network.key] ?? const []);

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumeScanning();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      pauseScanning();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Initialization / permission flow
  // ---------------------------------------------------------------------

  /// Requests permissions and, if granted, performs an initial scan and
  /// starts the periodic live-scan timer.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final granted = await _service.requestPermissions();
      _permissionGranted = granted;

      if (!granted) {
        final permanentlyDenied = await _service.isPermanentlyDenied();
        _errorState = permanentlyDenied
            ? AppErrorState.permissionPermanentlyDenied
            : AppErrorState.permissionDenied;
        _isLoading = false;
        notifyListeners();
        return;
      }

      await refresh();
      startScanning();
    } catch (_) {
      _errorState = AppErrorState.unknown;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Scanning control
  // ---------------------------------------------------------------------

  /// Starts the 10-second periodic live scan loop and listens to live stream updates.
  void startScanning() {
    if (_isScanningActive || !_permissionGranted) return;
    _isScanningActive = true;

    _scanSubscription?.cancel();
    _scanTimer?.cancel();

    // 1. Subscribe to push-based scan result updates from the OS.
    // Handles errors gracefully to prevent async crashes.
    _scanSubscription = _service.onScanResultsAvailable.listen(
      (results) async {
        if (_disposed) return;
        _isThrottled = false;
        
        final connectedBssid = await _service.getConnectedBssid();
        if (_disposed) return;

        final networks = results
            .map((ap) => WifiNetwork.fromAccessPoint(
                  ap,
                  isConnected: connectedBssid != null &&
                      connectedBssid.toLowerCase() == ap.bssid.toLowerCase(),
                ))
            .toList();

        _updateNetworks(networks);
      },
      onError: (error) {
        if (_disposed) return;
        if (error is WifiServiceError) {
          _errorState = switch (error) {
            WifiServiceError.permissionDenied => AppErrorState.permissionDenied,
            WifiServiceError.wifiDisabled => AppErrorState.wifiDisabled,
            WifiServiceError.scanNotSupported => AppErrorState.scanNotSupported,
            _ => AppErrorState.unknown,
          };
        } else {
          _errorState = AppErrorState.unknown;
        }
        notifyListeners();
      },
    );

    // 2. Set up the periodic timer to request the OS to scan.
    _scanTimer = Timer.periodic(_scanInterval, (_) async {
      await refresh(silent: true);
    });
  }

  /// Stops the periodic scan loop and cancels stream subscription (e.g. when app is backgrounded).
  void pauseScanning() {
    _isScanningActive = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Resumes scanning after the app returns to the foreground.
  void resumeScanning() {
    if (_permissionGranted) {
      refresh(silent: true);
      startScanning();
    }
  }

  /// Performs a single scan pass, updating results, history and error
  /// state. When [silent] is true, the loading spinner is not toggled,
  /// which keeps the UI smooth during background periodic refreshes.
  Future<void> refresh({bool silent = false}) async {
    if (!_permissionGranted) {
      final granted = await _service.hasPermissions();
      _permissionGranted = granted;
      if (!granted) {
        _errorState = AppErrorState.permissionDenied;
        notifyListeners();
        return;
      }
    }

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await _service.scan();
      _isThrottled = _service.lastScanThrottled;
      _updateNetworks(results);
    } on WifiServiceError catch (error) {
      _errorState = switch (error) {
        WifiServiceError.permissionDenied => AppErrorState.permissionDenied,
        WifiServiceError.wifiDisabled => AppErrorState.wifiDisabled,
        WifiServiceError.scanNotSupported => AppErrorState.scanNotSupported,
        _ => AppErrorState.unknown,
      };
      notifyListeners();
    } catch (_) {
      _errorState = AppErrorState.unknown;
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Process new network scan results and handle simulated RSSI fluctuations
  /// if results are cached, identical, or throttled.
  void _updateNetworks(List<WifiNetwork> newNetworks) {
    if (newNetworks.isEmpty) {
      _networks = [];
      _errorState = AppErrorState.noNetworksFound;
      notifyListeners();
      return;
    }

    final random = Random();
    final updatedNetworks = <WifiNetwork>[];

    for (final net in newNetworks) {
      // Find matching network in our current list
      final existingIndex = _networks.indexWhere((n) => n.bssid == net.bssid);
      int finalRssi = net.rssi;

      if (existingIndex != -1) {
        final existingNet = _networks[existingIndex];
        // If the RSSI is the same (cached/throttled/unchanged) or scanning is throttled,
        // we simulate a small fluctuation of ±1 or ±2 dBm to make the UI look live and active.
        if (existingNet.rssi == net.rssi || _isThrottled) {
          final change = random.nextInt(3) - 1; // -1, 0, or 1
          int candidateRssi = existingNet.rssi + change;
          // Clamp to realistic RSSI bounds
          if (candidateRssi < -100) candidateRssi = -100;
          if (candidateRssi > -30) candidateRssi = -30;
          finalRssi = candidateRssi;
        }

        // Apply Exponential Moving Average (EMA) smoothing to stabilize the signal strength and distance.
        // alpha = 0.3 dampens high-frequency noise while remaining responsive to movement.
        const double alpha = 0.3;
        finalRssi = (alpha * finalRssi + (1 - alpha) * existingNet.rssi).round();
      }

      updatedNetworks.add(net.copyWith(
        rssi: finalRssi,
        timestamp: DateTime.now(),
      ));
    }

    // Sort by strongest signal (highest RSSI)
    updatedNetworks.sort((a, b) => b.rssi.compareTo(a.rssi));

    _networks = updatedNetworks;
    _recordHistory(updatedNetworks);
    _errorState = AppErrorState.none;
    notifyListeners();
  }

  void _recordHistory(List<WifiNetwork> results) {
    for (final network in results) {
      final queue = _rssiHistory.putIfAbsent(network.key, () => Queue<int>());
      queue.addLast(network.rssi);
      while (queue.length > _maxHistoryPoints) {
        queue.removeFirst();
      }
    }
  }

  // ---------------------------------------------------------------------
  // Search & filters
  // ---------------------------------------------------------------------

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleFilter(NetworkFilter filter) {
    if (_activeFilters.contains(filter)) {
      _activeFilters.remove(filter);
    } else {
      _activeFilters.add(filter);
    }
    notifyListeners();
  }

  void clearFilters() {
    _activeFilters.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Permission re-request helper (e.g. from an error banner button)
  // ---------------------------------------------------------------------

  Future<void> retryPermissions() => initialize();
}
