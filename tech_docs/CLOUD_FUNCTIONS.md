# Cummins Command V2 — Cloud Functions

> All functions use 2nd generation Firebase Functions SDK (Node.js)

## Complete Cloud Functions List

| Function | Trigger | Gemini Model | Purpose |
|----------|---------|-------------|---------|
| `analyzeDrive` | `onDocumentCreated`: `drives/{driveId}` | 3.1 Pro | Post-drive analysis: summary, anomalies, health score, recommendations |
| `processAiJob` | `onDocumentCreated`: `aiJobs/{jobId}` | 3.1 Pro | Long-running AI tasks: range analysis, predictive maintenance, custom queries |
| `generateDashboard` | `onDocumentCreated`: `aiJobs/{jobId}` where `type=dashboard_generation` | 3.1 Pro | AI dashboard creation from natural language prompt |
| `checkPredictiveMaintenance` | Scheduled (daily) + `onDocumentCreated`: drives | 3.1 Pro | Trend analysis across all drives, generate maintenance predictions |
| `computeBaseline` | Scheduled (weekly) | 2.5 Flash | Compute 30-day rolling baseline averages for every parameter |
| `processVehicleShare` | `onDocumentCreated`: `sharing/{shareId}` | None | Send invite notification, set up cross-user access |
| `decodeVin` | `onDocumentCreated`: `vehicles/{vehicleId}` | None | NHTSA VIN decoder API call, populate vehicle specs |
| `exportDriveData` | `onDocumentCreated`: `aiJobs/{jobId}` where `type=export` | None | Generate CSV/JSON export file, upload to Cloud Storage |

## Function Trigger Paths (Full Firestore Paths)

```
users/{userId}/vehicles/{vehicleId}/drives/{driveId}        → analyzeDrive
users/{userId}/aiJobs/{jobId}                                → processAiJob / generateDashboard / exportDriveData
users/{userId}/vehicles/{vehicleId}/sharing/{shareId}        → processVehicleShare
users/{userId}/vehicles/{vehicleId}                          → decodeVin
Scheduled (daily cron)                                        → checkPredictiveMaintenance
Scheduled (weekly cron)                                       → computeBaseline
```

## AI Job Lifecycle (Realtime Progress Pattern)

### 1. Client Creates Job
```dart
await db.collection('users/$uid/aiJobs').add({
  'type': 'range_analysis',
  'vehicleId': 'abc123',
  'parameters': {
    'startDate': '2026-01-01',
    'endDate': '2026-02-20',
  },
  'status': 'queued',
  'progress': 0.0,
});
```

### 2. Client Listens for Realtime Updates
```dart
db.doc('users/$uid/aiJobs/$jobId').snapshots().listen((snap) {
  final status = snap['status'];     // 'queued' -> 'processing' -> 'complete'
  final progress = snap['progress']; // 0.0 -> 0.3 -> 0.7 -> 1.0
  final step = snap['currentStep'];  // 'Aggregating drive data...'
  // UI updates automatically with each change
});
```

### 3. Cloud Function Processes with Progress
```javascript
exports.processAiJob = onDocumentCreated(
  'users/{uid}/aiJobs/{jobId}',
  async (event) => {
    const ref = event.data.ref;

    await ref.update({
      status: 'processing',
      progress: 0.1,
      currentStep: 'Loading drives...'
    });

    // ... aggregate data ...
    await ref.update({ progress: 0.4, currentStep: 'Analyzing trends...' });

    // ... call Gemini 3.1 Pro ...
    await ref.update({ progress: 0.8, currentStep: 'Generating report...' });

    // ... write final result ...
    await ref.update({
      status: 'complete',
      progress: 1.0,
      result: geminiResponse
    });
  }
);
```

## analyzeDrive Function Detail

Triggered when a new drive document is created:

1. Reads all datapoints from the drive's `datapoints` subcollection
2. Aggregates statistics (max, min, avg for every parameter)
3. Loads vehicle context (year, make, model, mods, baseline)
4. Builds structured prompt with all context + explicit JSON output schema
5. Calls Gemini 3.1 Pro
6. Writes back to the drive document:
   - `aiSummary`: Plain English summary
   - `aiAnomalies`: Array of detected anomalies
   - `aiHealthScore`: 0–100 score
   - `aiRecommendations`: Array of actionable items
   - `status`: `"analysis_complete"`

## Prompt Engineering for Cloud Functions

Every Gemini call includes:
- Vehicle context (year, make, model, engine, mods, odometer)
- Parameter definitions (what each PID is, normal range for this engine)
- Historical context (last 10 drives summary, 30-day baseline averages)
- User thresholds (warning/critical levels)
- Current data being analyzed
- Explicit JSON output schema

### Thinking Configuration
Gemini 3.x uses `thinkingLevel` (enum), Gemini 2.5 uses `thinkingBudget` (token count).

| Job Type | Gemini 3.1 Pro (`thinkingLevel`) | Gemini 2.5 Flash (`thinkingBudget`) |
|----------|----------------------------------|--------------------------------------|
| Quick summaries | `low` | 256 |
| Deep analysis | `high` | 2048 |

## Cloud Functions Tech Stack

```
functions/
  package.json
    - firebase-functions (v7.x)  # 2nd gen SDK, requires Node.js 18+
    - firebase-admin
    - @google/genai               # Gemini 3.1 Pro server-side (replaces deprecated @google/generative-ai)
  index.js
    - analyzeDrive
    - processAiJob
    - generateDashboard
    - checkPredictiveMaintenance
    - computeBaseline
    - processVehicleShare
    - decodeVin
    - exportDriveData
```
