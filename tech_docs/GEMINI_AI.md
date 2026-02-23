# Cummins Command V2 — Gemini AI Integration

## Model Selection

| Model | Use Case | Path | Cost/Speed |
|-------|----------|------|------------|
| **Gemini 3.1 Pro** (`gemini-3.1-pro-preview`) | Deep analysis, drive summaries, predictive maintenance, dashboard generation, complex chat | Client SDK + Cloud Functions | Higher cost, thinking capable |
| **Gemini 2.5 Flash** (`gemini-2.5-flash`) | Quick summaries, gauge annotations, AI status strip, baseline computation | Client SDK + Cloud Functions | Lower cost, sub-second response |

Model version is dynamically switchable via **Firebase Remote Config** — no app update required.

## Dual AI Path Architecture

### Path 1: Firebase AI Logic Client SDK (Direct from App)

**Use cases**: Interactive chat, quick questions, dashboard generation, real-time gauge annotations

```dart
// GoogleAI backend (Gemini Developer API — free tier)
final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-3.1-pro-preview');
final response = await model.generateContent([Content.text(prompt)]);

// Or VertexAI backend (pay-as-you-go, enterprise features)
// final model = FirebaseAI.vertexAI().generativeModel(model: 'gemini-3.1-pro-preview');
```

- Uses `FirebaseAI.googleAI()` or `FirebaseAI.vertexAI()` static factory methods (NOT `GoogleAIBackend()` — that's the JS/Web SDK syntax)
- Calls Gemini directly from Flutter through Firebase's secure proxy
- No API key exposed in client code
- Protected by Firebase App Check
- Best for user-initiated, interactive tasks

### Path 2: Cloud Functions + Gemini API (Server-Side)

**Use cases**: Drive analysis, predictive maintenance, range analysis, batch processing

```javascript
// Called from Node.js Cloud Function using @google/genai SDK
// NOTE: @google/generative-ai is DEPRECATED — use @google/genai instead
const { GoogleGenAI } = require('@google/genai');
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
const response = await ai.models.generateContent({
  model: 'gemini-3.1-pro-preview',
  contents: prompt,
});
```

- Triggered by Firestore document writes
- Can read unlimited historical data from multiple collections
- Runs up to 9 minutes (2nd gen Cloud Functions)
- Processes results before user even opens the app

## Prompt Engineering Standards

Every Gemini call uses structured prompts with explicit JSON output schemas. Each prompt includes:

### Context Injection
1. **Vehicle context**: year, make, model, engine, mods, current odometer
2. **Parameter definitions**: what each PID is, normal range for this specific engine
3. **Historical context**: last 10 drives summary, 30-day baseline averages
4. **User thresholds**: user-configured warning/critical levels
5. **Current data**: the specific data being analyzed
6. **Output schema**: explicit JSON structure the model must return

### Thinking Configuration

Gemini models support thinking/reasoning with different APIs by generation:

**Gemini 3.x models** use `thinkingLevel` (enum-based):
| Level | Description |
|-------|-------------|
| `minimal` | Flash only — minimal reasoning |
| `low` | Light reasoning |
| `medium` | Moderate reasoning (Flash and 3 Pro) |
| `high` | Maximum reasoning (default, dynamic) |

**Gemini 2.5 models** use `thinkingBudget` (token-count-based):
| Job Type | Budget |
|----------|--------|
| Quick summaries | 256 tokens |
| Deep analysis | 2048 tokens |
| Dynamic | -1 (let model decide) |
| Max | 32,768 tokens |

For this app, Gemini 3.1 Pro uses `thinkingLevel: 'low'` for quick summaries and `thinkingLevel: 'high'` for deep analysis.

## AI Job Lifecycle (Realtime Progress)

### Client Creates Job

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

### Client Listens for Realtime Updates

```dart
db.doc('users/$uid/aiJobs/$jobId').snapshots().listen((snap) {
  final status = snap['status'];     // 'queued' -> 'processing' -> 'complete'
  final progress = snap['progress']; // 0.0 -> 0.3 -> 0.7 -> 1.0
  final step = snap['currentStep'];  // 'Aggregating drive data...'
  // UI updates automatically with each change
});
```

### Cloud Function Processes with Progress Updates

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

## AI Features by Screen

| Screen | AI Feature | Model | Path |
|--------|-----------|-------|------|
| Command Center | AI Status Strip (realtime) | 2.5 Flash | Client SDK |
| Command Center | Expanded gauge AI annotation | 2.5 Flash | Client SDK |
| Command Center | AI Dashboard Generation | 3.1 Pro | Client SDK |
| Data Explorer | "Ask Gemini about this data" | 3.1 Pro | Client SDK |
| Drive History | Post-drive analysis + summary | 3.1 Pro | Cloud Function |
| AI Insights | Today's Briefing | 3.1 Pro | Cloud Function |
| AI Insights | Health Score Dashboard | 3.1 Pro | Cloud Function |
| AI Insights | Predictive Maintenance | 3.1 Pro | Cloud Function (scheduled + triggered) |
| AI Insights | Ask Gemini Chat | 3.1 Pro | Client SDK |
| AI Insights | Range Analysis | 3.1 Pro | Cloud Function (with progress) |
| Maintenance | AI maintenance predictions | 3.1 Pro | Cloud Function |

## Firebase Remote Config for Model Switching

```dart
// Dynamic model selection without app update
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.fetchAndActivate();
final modelName = remoteConfig.getString('gemini_model_name');
// Returns 'gemini-3.1-pro-preview' or 'gemini-2.5-flash' etc.
```

## Firebase AI Monitoring

Token usage, latency, and error rates tracked in Firebase console via Firebase AI Monitoring.
