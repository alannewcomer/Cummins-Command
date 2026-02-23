# Cummins Command V2 — Technology Stack

> Verified February 2026

## Complete Stack Table

| Layer | Technology | Purpose | Notes |
|-------|-----------|---------|-------|
| **Framework** | Flutter 3.x (Dart) | Cross-platform mobile | Single codebase for iOS + Android |
| **State** | Riverpod 3.x (`flutter_riverpod` 3.2.1) | Reactive state management | Composable providers, auto-dispose, automatic retry, pause/resume, mutations |
| **AI — Client** | Firebase AI Logic SDK (`firebase_ai`) | Client-side Gemini calls | `gemini-3.1-pro-preview` model via GoogleAI or VertexAI backend |
| **AI — Server** | Cloud Functions 2nd Gen + Gemini 3.1 Pro | Heavy AI jobs | `onDocumentWritten` triggers, long-running analysis, structured JSON output |
| **AI — Fast** | Gemini 2.5 Flash | Quick summaries, annotations | Lower cost, sub-second for gauge annotations and quick context |
| **Database** | Cloud Firestore | Primary data store | Offline persistence enabled, `CACHE_SIZE_UNLIMITED`, realtime snapshot listeners |
| **Auth** | Firebase Auth | User accounts | Phone number auth + Google (Gmail) sign-in |
| **Storage** | Cloud Storage for Firebase | Large exports, backups | Drive data exports, PDF maintenance logs |
| **Push** | Firebase Cloud Messaging | Notifications | Critical alerts, AI predictions, maintenance reminders |
| **Remote Config** | Firebase Remote Config | Dynamic model switching | Swap Gemini model version without app update |
| **Bluetooth** | `flutter_bluetooth_classic_serial` (v1.3.2) | OBD adapter connection | Classic BT RFCOMM for OBDLink MX+ SPP. Supports Android, iOS, macOS, Linux, Windows. **Note:** `flutter_bluetooth_serial` is abandoned (last update Aug 2021, no Dart 3 support). |
| **Background** | `flutter_background_service` (v5.1.0) | Background data logging | Continues logging when app is backgrounded. **Risk:** Last updated Dec 2024 — evaluate against latest Android 14/iOS 17 background execution rules. Consider supplementing with `workmanager` for scheduled tasks. |
| **Charts** | Syncfusion Flutter Charts | Data visualization | 30+ chart types, crosshair, trackball, zoom, pan, real-time update |
| **Gauges** | Syncfusion Flutter Gauges | Radial + linear gauges | Animated, customizable, threshold-aware |
| **Maps** | Google Maps Flutter | GPS track overlay | Route recording with data overlay |
| **Monitoring** | Firebase AI Monitoring | AI usage tracking | Token usage, latency, error rates in Firebase console |

## Key Flutter Packages (pubspec.yaml)

### Core Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^3.2.1
  riverpod_annotation: ^4.0.2

  # Firebase
  firebase_core:
  firebase_auth:
  cloud_firestore:
  firebase_storage:
  firebase_messaging:
  firebase_remote_config:
  firebase_ai:                    # Client-side Gemini
  firebase_app_check:

  # Navigation
  go_router:

  # Bluetooth / OBD
  flutter_bluetooth_classic_serial: ^1.3.2

  # Background Processing
  flutter_background_service:

  # Charts & Gauges (Syncfusion)
  syncfusion_flutter_charts:
  syncfusion_flutter_gauges:

  # Maps
  google_maps_flutter:

  # Data Models
  freezed_annotation:
  json_annotation:

  # Typography
  google_fonts:                   # Orbitron, JetBrains Mono, Inter

  # Utilities
  intl:                           # Date/number formatting
  uuid:                           # Unique IDs
  geolocator:                     # GPS
  share_plus:                     # Social sharing
  path_provider:                  # File paths
  csv:                            # CSV export
```

### Dev Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints:
  build_runner:
  freezed: ^3.2.5
  json_serializable: ^6.13.0
  riverpod_generator: ^4.0.3
```

## Cloud Functions Stack (Node.js)

```
functions/
  package.json
  - firebase-functions (v7.x)    # 2nd gen, requires Node.js 18+
  - firebase-admin
  - @google/genai                 # Gemini 3.1 Pro server-side (replaces deprecated @google/generative-ai)
```

## Hardware Target

- **Vehicle**: 2026 Ram 2500 Laramie, 6.7L Cummins Diesel
- **OBD Adapter**: OBDLink MX+ (Bluetooth Classic, RFCOMM/SPP)
- **Protocols**: J1939 (Cummins-specific SPNs) + Standard OBD2 (Mode 01)
- **Data Rates**: 500ms to 5000ms per parameter tier
