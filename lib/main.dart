import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/wifi_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const WifiAnalyzerApp());
}

/// Root widget for the WiFi Analyzer application.
class WifiAnalyzerApp extends StatelessWidget {
  const WifiAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00E5FF),
      brightness: Brightness.dark,
    );

    return ChangeNotifierProvider(
      create: (_) => WifiProvider(),
      child: MaterialApp(
        title: 'WiFi Analyzer',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: darkScheme,
          scaffoldBackgroundColor: darkScheme.surface,
          appBarTheme: AppBarTheme(
            backgroundColor: darkScheme.surface,
            surfaceTintColor: darkScheme.surfaceTint,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: darkScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: CardTheme(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: darkScheme.primary,
            foregroundColor: darkScheme.onPrimary,
            shape: const StadiumBorder(),
          ),
          chipTheme: ChipThemeData(
            selectedColor: darkScheme.primaryContainer,
            backgroundColor: darkScheme.surfaceContainerHigh,
            labelStyle: TextStyle(color: darkScheme.onSurface),
            shape: const StadiumBorder(),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
