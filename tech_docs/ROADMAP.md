# Cummins Command V2 — Future Roadmap

> Post-launch modules. Architecture designed to enable all of these.

## Planned Features

| Feature | Description |
|---------|------------|
| **GPS Track Recording** | Overlay parameter data on map route. See where boost peaked on a mountain grade. |
| **Towing Mode** | Specialized dashboard with trailer weight input, grade estimation, safety alerts. |
| **Dyno Mode** | Estimate HP and torque from acceleration data, boost, and RPM curves. |
| **Fuel Cost Tracker** | Price per fill, cost per mile, fuel efficiency optimization suggestions. |
| **DTC Reader** | Read and clear diagnostic trouble codes with plain-English explanations from Gemini. |
| **Weather Correlation** | Correlate performance data with temperature, altitude, humidity. |
| **Community Benchmarks** | Opt-in anonymous data to compare your truck against others. |
| **Apple CarPlay / Android Auto** | Glanceable dashboard with critical gauges. |
| **Voice Assistant** | Gemini Live API integration for hands-free querying while driving. |
| **Mod Impact Analysis** | Save baseline before a mod. Compare after. AI quantifies the difference. |
| **Drive Scoring / Gamification** | Eco-driving scores, efficiency challenges, personal bests. |

## Architecture That Enables This

The V2 architecture was designed specifically so all of these can be added without breaking existing features:

- **All screens are independent feature modules** — adding a screen never touches existing code
- **Riverpod providers are composable** — new features add new providers, reuse existing ones
- **Firestore schema is additive** — new fields and collections never break old data
- **PID system is config-driven** — new PIDs added to a config file, app automatically supports them
- **Cloud Functions are independent** — new functions deploy without touching existing ones
- **Dashboard widget system is pluggable** — new widget types register in a factory, instantly available everywhere
- **AI prompts are versioned** — prompt templates stored in Remote Config, updatable without app release
