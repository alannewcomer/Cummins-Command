# Cummins Command V2 — Phased Build Plan

## Phase 1: Foundation (Weeks 1–2)

- Flutter project setup: Riverpod, Firebase, GoRouter, theme system
- Firebase project: Firestore, Auth (phone + Google sign-in), Cloud Functions 2nd gen, AI Logic
- Firestore offline persistence: `CACHE_SIZE_UNLIMITED`, verified on Android + iOS
- Bluetooth service: scan, connect, RFCOMM socket to OBDLink MX+
- AT command initialization sequence
- Basic OBD2 PID polling: RPM, coolant, speed, throttle
- Hex response parser for standard OBD2
- Multi-vehicle Firestore schema with CRUD operations

## Phase 2: Deep Data (Weeks 3–4)

- J1939 header configuration and protocol switching
- All Cummins-specific SPN request and response parsers
- Multi-rate polling scheduler (500ms / 1000ms / 2000ms / 5000ms tiers)
- Data model classes (Freezed) for every parameter
- Live data stream architecture with Riverpod providers
- PID definitions config system (config-driven, not hardcoded)
- GPS integration for location tracking

## Phase 3: Command Center + Gauges (Weeks 5–6)

- Syncfusion radial gauges with threshold color system
- Linear gauges, digital readouts, sparklines
- Dashboard configuration system: Firestore-backed layouts
- Prebuilt dashboard templates (all 8 templates)
- Dashboard editor: add/remove/reposition widgets, save/load
- Expanded gauge view with AI annotation placeholder
- Landscape compact strip mode
- Vehicle picker in header, vehicle switching

## Phase 4: Drive Recording + History (Weeks 7–8)

- Auto drive detection: start on movement, end on 5+ minutes stationary
- Drive session manager: creates drive document, writes datapoints
- Firestore batch writes every 5 seconds (local cache)
- Drive summary calculation at session end
- Upload status tracking with snapshot listener
- Drive history list with AI health score badges
- Drive detail screen with summary stats and chart views
- Drive tagging and search/filter

## Phase 5: Data Explorer (Weeks 9–11)

- Parameter picker with full searchable PID list
- Time range selector with presets and custom range
- Syncfusion `SfCartesianChart` with zoom, pan, crosshair, trackball
- Multi-parameter overlay with independent Y-axes
- Statistical analysis panel (min, max, mean, std dev, percentiles)
- Annotation markers (regen events, alerts, drive boundaries)
- Period comparison (overlay two time ranges)
- Chart export as PNG, data export as CSV
- Deep-link from any gauge tap to Data Explorer for that parameter

## Phase 6: AI Integration (Weeks 12–14)

- Firebase AI Logic client SDK setup (`firebase_ai` package)
- Firebase Remote Config for dynamic model switching
- Cloud Function: `analyzeDrive` with Gemini 3.1 Pro
- Cloud Function: `processAiJob` with realtime progress updates
- AI status strip on Command Center (Gemini 2.5 Flash for speed)
- AI health score dashboard with sub-scores
- Predictive maintenance Cloud Function (scheduled + triggered)
- Ask Gemini chat interface with full truck context
- Range analysis with progress indicator
- AI dashboard generation flow
- AI annotation on expanded gauge view
- "Ask Gemini about this data" button in Data Explorer

## Phase 7: Sharing + Alerts + Maintenance (Weeks 15–16)

- Vehicle sharing: invite by email, invite by link, permissions management
- Alert threshold system: every parameter configurable
- Real-time alert overlay and haptic feedback
- FCM push notifications for critical alerts and AI predictions
- Maintenance log CRUD with categories, cost tracking, reminders
- AI maintenance predictions integrated into maintenance screen
- PDF export of maintenance log

## Phase 8: Polish + Launch (Weeks 17–18)

- Smooth animations throughout: page transitions, gauge updates, chart interactions
- Onboarding flow: OBDLink connect, VIN decode, dashboard selection, feature tour
- Settings screen: all preferences, data management, AI configuration
- Performance profiling: 60fps on dashboard, fast chart rendering
- Error handling: Bluetooth loss, bad PID responses, network issues
- Community dashboard browsing (basic — expand post-launch)
- App Store metadata, screenshots, descriptions
- Beta release to Cummins community for feedback
