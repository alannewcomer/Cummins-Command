import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'providers/auth_provider.dart' show initGoogleSignIn;
import 'services/background_service.dart';
import 'services/diagnostic_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Google Sign-In with web client ID (required by v7.x on Android)
  await initGoogleSignIn();

  // Configure background service (foreground notification keeps process alive
  // for Bluetooth reconnect when app is backgrounded)
  await initializeBackgroundService();

  // Configure Firestore for offline-first with unlimited cache
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Load dev-log cloud upload preference before auth listener
  await diag.loadCloudUploadPreference();

  // Enable diagnostic logging to Firestore when user is authenticated
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      diag.enableFirestore(user.uid);
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
