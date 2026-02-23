# Cummins Command V2 — Flutter Project Structure

```
lib/
├── main.dart
│
├── app/
│   ├── router.dart                    # GoRouter navigation
│   └── theme.dart                     # Colors, typography, gauge themes
│
├── features/
│   ├── command_center/                # Home screen + AI status strip
│   ├── data_explorer/                 # Full time-series explorer
│   ├── drive_history/                 # Drive list + drive detail
│   ├── ai_insights/                   # AI screen: health, predictions, chat, range
│   ├── maintenance/                   # Service log
│   ├── settings/                      # Preferences, vehicle management, sharing
│   ├── dashboards/                    # Dashboard editor, templates, AI generation
│   └── vehicles/                      # Vehicle CRUD, sharing, switching
│
├── services/
│   ├── bluetooth_service.dart
│   ├── obd_service.dart               # AT commands, PID polling scheduler
│   ├── j1939_parser.dart
│   ├── obd2_parser.dart
│   ├── drive_recorder.dart            # Session management + Firestore writes
│   ├── ai_service.dart                # Firebase AI Logic client SDK wrapper
│   ├── ai_job_service.dart            # AI job creation + snapshot listener
│   ├── alert_service.dart
│   └── share_service.dart             # Vehicle sharing logic
│
├── models/                            # Freezed classes
│   ├── vehicle.dart
│   ├── vehicle_data.dart
│   ├── drive_session.dart
│   ├── datapoint.dart
│   ├── dashboard_config.dart
│   ├── ai_job.dart
│   ├── maintenance_record.dart
│   ├── share_record.dart
│   └── alert.dart
│
├── providers/
│   ├── bluetooth_provider.dart
│   ├── live_data_provider.dart
│   ├── vehicle_provider.dart
│   ├── drives_provider.dart
│   ├── dashboard_provider.dart
│   ├── ai_provider.dart
│   ├── ai_job_provider.dart           # Snapshot listener for job progress
│   ├── maintenance_provider.dart
│   └── data_explorer_provider.dart
│
├── widgets/
│   ├── gauges/                        # Reusable gauge widgets
│   ├── charts/                        # Reusable chart widgets + Data Explorer components
│   ├── cards/                         # Drive cards, alert cards, stat cards
│   ├── dashboard_widgets/             # All dashboard widget renderers
│   ├── ai/                            # AI status strip, chat bubble, progress indicator
│   └── common/
│
└── config/
    ├── pid_config.dart                # All OBD2 + J1939 PID definitions
    ├── thresholds.dart                # Default alert thresholds for 6.7L Cummins
    ├── dashboard_templates.dart       # Prebuilt dashboard JSON configs
    └── constants.dart
```

## Cloud Functions Structure

```
functions/
├── package.json
├── index.js                           # Main entry, exports all functions
├── analyzeDrive.js
├── processAiJob.js
├── generateDashboard.js
├── checkPredictiveMaintenance.js
├── computeBaseline.js
├── processVehicleShare.js
├── decodeVin.js
└── exportDriveData.js
```

## Key Architecture Principles

- **Feature-first**: Each feature is a self-contained module under `features/`
- **Independent screens**: Adding a screen never touches existing code
- **Composable providers**: New features add new providers, reuse existing ones
- **Config-driven PIDs**: New PIDs added to `pid_config.dart`, app automatically supports them
- **Pluggable widgets**: New dashboard widget types register in a factory
- **Additive schema**: New Firestore fields/collections never break old data
- **Independent Cloud Functions**: New functions deploy without touching existing ones
- **Versioned AI prompts**: Prompt templates stored in Remote Config, updatable without app release
