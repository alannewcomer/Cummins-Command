# Cummins Command V2 — Firestore Data Schema

> Every byte captured, surfaced, and AI-ready

## Collection Structure Overview

```
users/{userId}
├── profile: name, email, phone, avatar, authProvider (phone|google)
├── preferences: units, theme, defaultDashboard, alertSounds, haptics
├── stats: totalDrives, totalMiles, totalFuelGallons, lifetimeEngineHours, totalRegens
├── aiContext: lastHealthScore, lastAnalysisDate, baselineData (30-day rolling averages)
│
├── vehicles/{vehicleId}
│   ├── year, make, model, trim, vin, engine, transmissionType
│   ├── currentOdometer, purchaseDate, purchaseMileage
│   ├── towingCapacity, payloadCapacity, gvwr
│   ├── isActive (boolean — which vehicle is currently selected)
│   ├── modHistory: array of mods with dates (intake, exhaust, tuner, etc.)
│   ├── baselineSnapshots: AI-generated baseline data at stock and after each mod
│   │
│   ├── drives/{driveId}
│   │   ├── startTime, endTime, durationSeconds
│   │   ├── startOdometer, endOdometer, distanceMiles
│   │   ├── fuelUsedGallons, averageMPG, instantMPGMin, instantMPGMax
│   │   ├── maximums: maxBoostPsi, maxEgtF, maxCoolantTempF, maxTransTempF,
│   │   │             maxOilTempF, maxTurboSpeedRpm, maxRailPressurePsi
│   │   ├── averages: avgBoost, avgEgt, avgCoolant, avgTrans, avgLoad, avgRpm
│   │   ├── dpfRegenOccurred, dpfRegenCount, dpfRegenDurationSeconds
│   │   ├── gpsStartLat, gpsStartLng, gpsEndLat, gpsEndLng
│   │   ├── weatherTemp, weatherConditions (if weather API integrated)
│   │   ├── status: "recording" | "pending_upload" | "uploaded" | "pending_analysis" | "analysis_complete"
│   │   ├── aiSummary: string
│   │   ├── aiAnomalies: array
│   │   ├── aiHealthScore: 0-100
│   │   ├── aiRecommendations: array
│   │   ├── tags: user-applied labels ("towing", "commute", "mountain", "track")
│   │   │
│   │   └── datapoints/{timestamp}
│   │       ├── timestamp (milliseconds since epoch)
│   │       ├── ALL OBD2 PIDs: rpm, speed, coolantTemp, intakeTemp, maf,
│   │       │   throttlePos, fuelPressure, fuelTrim, etc.
│   │       ├── ALL J1939 SPNs: boostPressure, egt, turboSpeed, dpfSootLoad,
│   │       │   dpfRegenStatus, defLevel, defTemp, railPressure, oilPressure,
│   │       │   oilTemp, transTemp, fuelRate, engineLoad, barometricPressure,
│   │       │   ambientTemp, etc.
│   │       ├── GPS: lat, lng, altitude, speed, heading
│   │       └── Calculated: instantMPG, estimatedGear, estimatedHP, estimatedTorque
│   │
│   ├── sharing/{shareId}
│   │   ├── sharedWithUserId or sharedWithEmail
│   │   ├── permissions: { viewLive, viewHistory, viewAI, viewMaintenance, editMaintenance, manageDashboards }
│   │   ├── status: "pending" | "accepted" | "revoked"
│   │   ├── inviteCode: short code for link-based sharing
│   │   └── createdAt, acceptedAt
│   │
│   ├── dashboards/{dashboardId}
│   │   ├── name, description, icon, isDefault
│   │   ├── source: "user" | "ai_generated" | "template" | "community"
│   │   ├── layout: array of widget definitions (type, parameter, position, size, thresholds, color)
│   │   └── aiPrompt: the prompt used to generate this dashboard (if AI-generated)
│   │
│   └── maintenance/{recordId}
│       └── (Same as V1 + cost tracking, parts data, AI prediction linkage)
│
└── aiJobs/{jobId}
    ├── type: "drive_analysis" | "range_analysis" | "predictive_maintenance" | "custom_query" | "dashboard_generation"
    ├── parameters: { dateRange, vehicleId, query, etc. }
    ├── status: "queued" | "processing" | "complete" | "failed"
    ├── progress: 0.0 to 1.0 (updated by Cloud Function during processing)
    ├── currentStep: human-readable step description
    ├── result: the full AI response (structured JSON)
    ├── model: which Gemini model was used
    ├── tokensUsed: input and output token count
    └── createdAt, startedAt, completedAt
```

## Global Collections

```
dashboardTemplates/{templateId}
  └── Curated dashboard templates available to all users
      (Daily Driver, Towing, Mountain, Track Day, Economy, Winter, Break-In)

communityDashboards/{dashboardId}
  └── User-shared dashboards with ratings and install counts

pidDefinitions/{pidId}
  └── Master list of all OBD2 and J1939 PIDs with display names,
      units, formulas, normal ranges, and AI context strings
```

## Critical Design Notes

### Datapoints are RAW data
These are NOT summaries. These are the actual raw readings at 500ms–5000ms intervals. The Data Explorer reads these directly.

### Vehicles are a subcollection
Vehicles are `users/{userId}/vehicles/{vehicleId}`, NOT fields on the user profile. This enables:
- Multi-vehicle support
- Per-vehicle isolation (drives, dashboards, maintenance, AI context)
- Sharing system

### Drive Status Flow
```
"recording" → "pending_upload" → "uploaded" → "pending_analysis" → "analysis_complete"
```

### AI Job Status Flow
```
"queued" → "processing" → "complete" | "failed"
```
