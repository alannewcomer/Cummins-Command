# Cummins Command V2 — Architecture Overview

> AI-First Diesel Intelligence Platform
> 2026 Ram 2500 Laramie | 6.7L Cummins Diesel

## Core Philosophy: AI-First, Not AI-Added

V1 treated AI as a feature. V2 treats AI as the **foundation**. Every screen, every interaction, every data point flows through an intelligence layer. The AI is not a tab you visit — it is the fabric of the entire experience.

### What AI-First Means in Practice

1. **Every screen has an AI context bar** — The dashboard doesn't just show gauges. A persistent AI strip at the top says *"Boost response is 12% faster than your 30-day baseline. Engine is running optimally."* This updates in realtime.

2. **AI interprets before you ask** — You never wonder if a number is good or bad. Every value is annotated with AI context: green/amber/red with a plain-English reason.

3. **AI drives navigation** — The home screen is a command center where AI tells you what matters RIGHT NOW. *"Your fuel filter is at 84% of service life. Trans temps ran hot on your last tow. Here's what to watch."*

4. **AI generates dashboards** — Tell Gemini "build me a towing dashboard" and it creates a custom layout with the right gauges, thresholds, and alerts — on the fly.

5. **Every data point feeds AI** — Nothing is captured just to be stored. Every PID, every datapoint, every drive session is structured so AI can reason about it across time.

## V1 vs V2 Comparison

| Area | V1 (Previous) | V2 (This Document) |
|------|---------------|---------------------|
| AI Role | Feature tab with chat + summaries | Foundation layer — AI present on every screen, every interaction |
| Dashboard | Fixed 6-gauge grid | Fully customizable + AI-generated layouts + preset templates + community sharing |
| Data Access | Gauges + drive history charts | Full Data Explorer with time-series inspection, math, overlays, crosshair, zoom, statistical analysis |
| Data Surfacing | Summary stats on drive cards | Every captured parameter is browsable, chartable, exportable, and AI-queryable at any granularity |
| Firebase Pattern | Write locally, sync later | Reactive Firestore: write triggers Cloud Function → Gemini processes → writes result → realtime listener updates UI |
| Gemini Model | 1.5 Pro / Flash | Gemini 3.1 Pro (gemini-3.1-pro-preview) via Firebase AI Logic + Cloud Functions |
| Multi-Vehicle | Not specified | Full multi-vehicle with add, switch, share, permissions, and per-vehicle AI context |
| Customization | Drag and drop gauge positions | AI-generated dashboards, template library, parameter picker for any screen, saved profiles, community presets |
| Data Explorer | Not present | Dedicated screen: time-series browser, multi-overlay, crosshair inspection, statistical math, zoom to millisecond, export |
| Onboarding | Basic connect flow | AI-guided setup: VIN decode, auto-detect engine, suggest dashboards, explain every feature |

## High-Level Data Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  OBDLink MX+ │────▶│  Flutter App  │────▶│  Firestore       │
│  (Bluetooth) │     │  (Local Cache)│     │  (Cloud Sync)    │
└─────────────┘     └──────┬───────┘     └────────┬────────┘
                           │                       │
                    ┌──────▼───────┐     ┌────────▼────────┐
                    │ Firebase AI   │     │ Cloud Functions   │
                    │ Logic SDK     │     │ 2nd Gen           │
                    │ (Client-side) │     │ (Server-side)     │
                    └──────┬───────┘     └────────┬────────┘
                           │                       │
                    ┌──────▼───────────────────────▼──────┐
                    │         Gemini 3.1 Pro / 2.5 Flash   │
                    └──────────────────────────────────────┘
```

## The Reactive Firebase Loop (Core Pattern)

This is the single most important architectural pattern:

1. **App writes** a request document to Firestore
2. **Cloud Function triggers** on that write (`onDocumentCreated` / `onDocumentWritten`)
3. **Function calls** Gemini 3.1 Pro
4. **Function writes result** back to the same or related document
5. **App's realtime snapshot listener fires** → UI updates instantly

**No polling. No manual refresh. Instant.**

## Key Architectural Decisions

- **Offline-first during drives**: Zero network usage during active drives. All writes go to local Firestore cache. Automatic sync when drive ends.
- **Dual AI paths**: Client-side (Firebase AI Logic SDK) for interactive/quick tasks, Server-side (Cloud Functions + Gemini API) for heavy analysis.
- **Config-driven PID system**: New PIDs added to config, app automatically supports them.
- **Feature-modular structure**: Independent feature modules — adding a screen never touches existing code.
- **Composable state**: Riverpod providers are composable — new features add new providers, reuse existing ones.
- **Additive schema**: New Firestore fields and collections never break old data.
