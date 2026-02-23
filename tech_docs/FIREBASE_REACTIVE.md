# Cummins Command V2 — Firebase Reactive Architecture

> The single most important architectural pattern in the app

## The Reactive Loop

```
App writes request    Cloud Function       Function calls       Function writes      Snapshot listener
to Firestore      →   triggers on write →  Gemini 3.1 Pro   →  result to Firestore → fires → UI updates
```

**No polling. No refresh. Instant.**

## How It Works for AI Analysis (Drives)

1. **Drive ends** → App writes drive summary document to Firestore with `status: "pending_analysis"`
2. **Cloud Function fires** → `onDocumentCreated` for the drives collection
3. **Function aggregates** datapoints, builds structured prompt, calls Gemini 3.1 Pro API
4. **Function writes** `aiSummary`, `aiAnomalies`, `aiHealthScore`, and `status: "complete"` back to the drive document
5. **App's snapshot listener** on the drive document fires the moment the Cloud Function writes → UI updates instantly

## How It Works for Long-Running AI Jobs

For heavy analysis (range analysis, predictive maintenance, custom AI queries):

1. **App creates** an AI job document: `users/{userId}/aiJobs/{jobId}` with type, parameters, and `status: "queued"`
2. **Cloud Function triggers** → `onDocumentCreated` on aiJobs collection → Updates `status` to `"processing"` → App sees this immediately via snapshot listener, shows progress indicator
3. **Function runs the job** → For multi-step analysis, updates `progress` field (e.g., `progress: 0.5, currentStep: "Analyzing coolant trends"`) → Each update fires snapshot listener → UI shows live progress
4. **Function completes** → Writes full result to job document, sets `status: "complete"` → UI transitions from progress to results instantly

## Firestore Offline Persistence

Firestore offline persistence is **enabled by default** on Android and iOS. Key behaviors:

- Reads, writes, and queries work against local cache when offline
- When connectivity returns, all queued writes sync automatically
- Queued writes **survive app restart** — persist on disk

### Configuration

```dart
db.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

Setting `CACHE_SIZE_UNLIMITED` disables LRU garbage collection, ensuring drive data is never evicted from the local cache. Critical because drives can generate tens of thousands of datapoints.

### During-Drive Write Strategy

- **Zero network usage during drives** — All writes go to local Firestore cache. No reads or writes hit the network.
- **Automatic sync after drive** — When drive ends and connectivity is available, Firestore automatically syncs all queued writes. No custom sync code needed.
- **Queued writes survive app restart** — If app is killed or phone restarts, queued writes persist on disk and sync when app reopens.

## Realtime Snapshot Listeners

Every screen that displays AI results, health scores, or analysis uses Firestore snapshot listeners. These are persistent connections that fire a callback whenever the underlying document changes — whether from the local app, a Cloud Function, or another device.

```dart
FirebaseFirestore.instance
    .collection('users').doc(userId)
    .collection('drives').doc(driveId)
    .snapshots()
    .listen((snapshot) {
      // UI rebuilds automatically when Cloud Function writes AI results
      final drive = DriveSession.fromFirestore(snapshot);
      ref.read(driveProvider.notifier).update(drive);
    });
```

**Flow**: Cloud Function finishes Gemini analysis → writes to Firestore → snapshot listener fires on user's phone → UI updates. No polling. No manual refresh. Instant.

## Cloud Functions 2nd Gen Triggers

All Cloud Functions use the 2nd generation Firebase Functions SDK with Firestore triggers:

```javascript
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

exports.analyzeDrive = onDocumentCreated(
  'users/{userId}/drives/{driveId}',
  async (event) => {
    const drive = event.data.data();
    // ... aggregate datapoints, call Gemini 3.1 Pro, write results back
  }
);
```

### Key 2nd Gen Advantages
- Up to **9 minutes** execution time (vs 60s for 1st gen)
- Better scaling and concurrency control
- Firestore document triggers (`onDocumentCreated`, `onDocumentWritten`)

## Gemini Integration: Dual Path

### Path 1: Firebase AI Logic Client SDK (Direct from App)

- **Use case**: Interactive chat, quick questions, dashboard generation, real-time gauge annotations
- **Model**: `gemini-3.1-pro-preview` or `gemini-2.5-flash` (via Firebase Remote Config for dynamic switching)
- **How**: Firebase AI Logic SDK (`firebase_ai` package) calls Gemini directly from Flutter through Firebase's secure proxy. No API key exposed in client code.
- **Security**: Firebase App Check protects against unauthorized API usage.

```dart
// GoogleAI backend (Gemini Developer API — free tier)
final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-3.1-pro-preview');
final response = await model.generateContent([Content.text(prompt)]);

// Or VertexAI backend (pay-as-you-go, enterprise features)
// final model = FirebaseAI.vertexAI().generativeModel(model: 'gemini-3.1-pro-preview');
```

### Path 2: Cloud Functions + Gemini API (Server-Side)

- **Use case**: Drive analysis, predictive maintenance, range analysis, batch processing, any job needing large historical data
- **Model**: `gemini-3.1-pro-preview` called from Node.js Cloud Function using Google AI SDK
- **How**: Cloud Function triggered by Firestore write → Aggregates data from multiple collections → Builds comprehensive prompt → Calls Gemini → Writes structured JSON result back to Firestore
- **Advantage**: Server-side functions can read unlimited historical data, run for up to 9 minutes, and process results before user even opens the app
