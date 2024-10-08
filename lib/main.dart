import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:primea/route_information_parser.dart';
import 'package:primea/router_delegate.dart';
import 'package:primea/util/analytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const errorTable = 'errors';

final supabase = Supabase.instance.client;

Future<void> reportError(FlutterErrorDetails details) async {
  await supabase.from(errorTable).insert({
    'error': details.exceptionAsString(),
    'library': details.library,
    'stack': details.stack.toString(),
    'context': details.context.toString(),
  });
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Supabase
      await Supabase.initialize(
        url: 'https://fdrysfgctvdtvrxpldxb.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZkcnlzZmdjdHZkdHZyeHBsZHhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjEyNDMyMjgsImV4cCI6MjAzNjgxOTIyOH0.7wcpER7Kch2A9zm5MiTKowd7IQ3Q2jSVkDytGzdTZHU',
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: true,
        ),
      );

      // Set up error handling
      FlutterError.onError = (details) {
        if (kReleaseMode) {
          reportError(details);
        }
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (kReleaseMode) {
          reportError(FlutterErrorDetails(exception: error, stack: stack));
        }
        return false;
      };

      runApp(App(title: 'Primea'));
    },
    (error, stackTrace) {
      final details = FlutterErrorDetails(exception: error, stack: stackTrace);
      if (kReleaseMode) {
        reportError(details);
      }
      FlutterError.presentError(details);
    },
  );
}

class App extends StatelessWidget {
  App({super.key, required this.title})
      : _routerDelegate = PrimeaRouterDelegate(title),
        _routeInformationParser = PrimeaRouteInformationParser();

  final String title;

  final PrimeaRouterDelegate _routerDelegate;
  final PrimeaRouteInformationParser _routeInformationParser;

  @override
  Widget build(BuildContext context) {
    Analytics.instance.trackEvent("load", {"page": "main"});

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFDEF141),
        brightness: Brightness.dark,
      ),
      cardTheme: const CardTheme(
        shape: ContinuousRectangleBorder(),
      ),
      fontFamily: 'Krypton',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        displayMedium: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        displaySmall: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        headlineLarge: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        headlineMedium: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        headlineSmall: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        titleLarge: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        titleMedium: TextStyle(
          fontVariations: [FontVariation('wght', 500)],
        ),
        titleSmall: TextStyle(
          fontVariations: [FontVariation('wght', 500)],
        ),
        bodyLarge: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        bodyMedium: TextStyle(
          fontVariations: [FontVariation('wght', 600)],
        ),
        bodySmall: TextStyle(
          fontVariations: [FontVariation('wght', 400)],
        ),
        labelLarge: TextStyle(
          fontVariations: [FontVariation('wght', 500)],
        ),
        labelMedium: TextStyle(
          fontVariations: [FontVariation('wght', 500)],
        ),
        labelSmall: TextStyle(
          fontVariations: [FontVariation('wght', 500)],
        ),
      ),
    );

    return SafeArea(
      child: MaterialApp.router(
        title: title,
        theme: theme,
        routerDelegate: _routerDelegate,
        routeInformationParser: _routeInformationParser,
      ),
    );
  }
}
