import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'providers/auth_provider.dart' show initGoogleSignIn;
import 'package:permission_handler/permission_handler.dart';
import 'services/background_service.dart';
import 'services/diagnostic_service.dart';

void main() async {
  // Catch all uncaught async errors and log them to Firestore via diag service
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase first (Crashlytics depends on it)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Crashlytics — captures native + Dart crashes remotely
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    // Catch Flutter framework errors (widget build errors, etc.)
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      diag.error('CRASH', 'FlutterError: ${details.exceptionAsString()}',
          details.stack?.toString());
    };

    // Catch platform dispatcher errors (unhandled async errors from platform channels)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      diag.error('CRASH', 'PlatformError: $error', stack.toString());
      return true;
    };

    // Lock orientation to portrait (primary) for dashboard readability
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Dark status bar for immersive dark theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Initialize Google Sign-In with web client ID (required by v7.x on Android)
    await initGoogleSignIn();

    // Request notification permission early (Android 13+ requires it for
    // foreground service notifications — must be granted BEFORE startForeground)
    await Permission.notification.request();

    // Request precise GPS location permission early — required for GPS route
    // tracking during drives. Must be granted before drive recording starts.
    // On Android 12+, ACCESS_FINE_LOCATION grants precise location.
    final locationStatus = await Permission.locationWhenInUse.request();
    if (locationStatus.isGranted || locationStatus.isLimited) {
      // Also ensure precise location is granted (Android 12+ can grant
      // approximate-only even when FINE is requested)
      final preciseStatus = await Permission.location.status;
      if (!preciseStatus.isGranted) {
        await Permission.location.request();
      }
    }

    // Configure background service (foreground notification keeps process alive
    // for Bluetooth reconnect when app is backgrounded)
    await initializeBackgroundService();

    // Configure Firestore for offline-first with unlimited cache
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Load dev-logs cloud upload preference before auth listener
    await diag.loadCloudPreference();

    // Enable diagnostic logging to Firestore when user is authenticated
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        diag.enableFirestore(user.uid);
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        diag.info('APP', 'Auth ready, diagnostics enabled', user.uid);
      } else {
        diag.disableFirestore();
      }
    });

    runApp(
      const ProviderScope(
        child: CumminsCommandApp(),
      ),
    );
  }, (error, stack) {
    // Last resort: catch anything that escaped all other handlers
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    diag.error('CRASH', 'Uncaught: $error', stack.toString());
  });
}

class CumminsCommandApp extends ConsumerWidget {
  const CumminsCommandApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Cummins Command',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
