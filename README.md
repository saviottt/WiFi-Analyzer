# WiFi Analyzer

A production-ready Flutter application for scanning and analyzing nearby
WiFi networks: live signal strength, channel/band detection, security
classification, RSSI history graphs and CSV export.

> **Android only.** WiFi scanning APIs (`wifi_scan`) are only supported on
> Android; iOS does not expose third-party WiFi scan APIs.

## Requirements

- Flutter SDK **3.32.0** or newer (`flutter --version`)
- Dart SDK **3.4.0** or newer (bundled with Flutter)
- Android Studio (or standalone Android SDK/cmdline-tools) with:
  - Android SDK Platform **34** (Android 14)
  - Android SDK Build-Tools **34.0.0**
  - Android NDK (installed automatically by Flutter if required)
- A physical Android device running **Android 6.0 (API 23)** or newer.
  Emulators generally cannot return real WiFi scan results — use a
  physical device for meaningful data.

## 1. Get the project

Unzip/copy this project folder, then from the project root:

```bash
flutter --version        # confirm >= 3.32.0
flutter doctor -v        # confirm no blocking issues
```

## 2. Configure the Flutter/Android SDK path

Open `android/local.properties` and replace the placeholder paths with
your actual SDK locations, for example:

```properties
sdk.dir=/Users/you/Library/Android/sdk
flutter.sdk=/Users/you/flutter
```

Alternatively, delete `android/local.properties` and run:

```bash
flutter create . --platforms=android
```

which regenerates it automatically to match your local environment
(this will not overwrite the existing `lib/` source files).

## 3. Install dependencies

```bash
flutter pub get
```

## 4. Connect a device and run

```bash
flutter devices           # confirm your Android device is listed
flutter run --release     # or omit --release for a debug build
```

On first launch the app will prompt for:

- **Location** permission (required by Android to read SSIDs from scan
  results on all versions)
- **Nearby WiFi Devices** permission (Android 13+ / API 33+)

Grant both for full functionality. If permissions are denied
permanently, the app surfaces a button that opens system Settings.

## 5. Build a release APK

```bash
flutter build apk --release
```

The output APK is generated at:

```
build/app/outputs/flutter-apk/app-release.apk
```

To build an Android App Bundle (for Play Store):

```bash
flutter build appbundle --release
```

> The provided `build.gradle` signs release builds with the **debug**
> keystore for convenience. Before publishing, configure a proper release
> `signingConfig` in `android/app/build.gradle`.

## Project structure

```
lib/
  main.dart                        # App entry point, Material 3 dark theme
  models/
    wifi_network.dart              # WifiNetwork domain model + enums
  services/
    wifi_service.dart              # wifi_scan / network_info_plus wrapper
  providers/
    wifi_provider.dart             # ChangeNotifier: scanning lifecycle, filters, history
  screens/
    home_screen.dart               # List, search, filters, refresh FAB, export
    network_details_screen.dart    # Full network metadata view
    rssi_graph_screen.dart         # Live RSSI line chart (fl_chart)
  widgets/
    network_card.dart              # List item card
    signal_indicator.dart          # Signal bars + color coding
    search_and_filters.dart        # SearchBar + FilterChip row
    status_view.dart               # Error / empty state UI
  utils/
    wifi_utils.dart                # Channel calc, band, security, distance
    csv_exporter.dart              # CSV export to local storage
android/
  app/
    build.gradle                   # compileSdk 34 / targetSdk 34, minSdk 23
    src/main/AndroidManifest.xml   # WiFi/location/nearby-devices permissions
    src/main/kotlin/.../MainActivity.kt
```

## Features implemented

- Material 3 dark theme, pull-to-refresh, animated floating refresh button
- Live scanning every 2 seconds; auto-pauses when app is backgrounded and
  resumes on foreground (via `WidgetsBindingObserver`)
- Per-network: SSID, BSSID, RSSI, frequency, channel, band, security type,
  signal bars, estimated distance, connected status
- List auto-sorted by strongest signal
- Tap a network for a live RSSI line chart (last 60 readings) with
  average / max / min stats, powered by `fl_chart`
- Search by SSID or MAC address
- Filter chips: 2.4GHz, 5GHz, Open, WPA, WPA2, WPA3
- CSV export (SSID, BSSID, RSSI, Frequency, Channel, Band, Security,
  Timestamp) saved to local device storage
- Graceful handling of denied/permanently-denied permissions, disabled
  WiFi, unsupported devices and empty scan results

## Troubleshooting

- **"No networks found" immediately after granting permissions**: some
  OEMs throttle scan frequency to ~1 scan per few seconds system-wide;
  wait a few seconds and pull to refresh.
- **Permissions dialog doesn't appear**: check that you haven't
  previously denied permissions permanently — use the in-app "Open
  Settings" button, or manually enable Location under
  Settings → Apps → WiFi Analyzer → Permissions.
- **Gradle sync fails**: confirm `android/local.properties` points to a
  valid Flutter SDK and Android SDK install, and that Android SDK
  Platform 34 + Build-Tools 34.0.0 are installed via Android Studio's
  SDK Manager.
