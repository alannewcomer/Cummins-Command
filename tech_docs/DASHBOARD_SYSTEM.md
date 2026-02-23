# Cummins Command V2 — Dashboard System

> Extreme customization + great defaults. Never stuck with a layout, never have to build from scratch.

## Dashboard Configuration Schema

Each dashboard is a JSON document stored in Firestore:

```json
{
  "name": "Mountain Towing",
  "source": "ai_generated",
  "aiPrompt": "Build a dashboard for towing in the mountains",
  "layout": {
    "columns": 3,
    "rows": 4,
    "widgets": [
      {
        "type": "radialGauge",
        "param": "egt",
        "col": 0,
        "row": 0,
        "colSpan": 1,
        "rowSpan": 1,
        "thresholds": { "warn": 1100, "crit": 1400 }
      },
      {
        "type": "radialGauge",
        "param": "transTemp",
        "col": 1,
        "row": 0
      },
      {
        "type": "sparkline",
        "param": "coolantTemp",
        "col": 2,
        "row": 2
      },
      {
        "type": "digital",
        "param": "altitude",
        "col": 0,
        "row": 3
      },
      {
        "type": "linearBar",
        "param": "dpfSoot",
        "col": 1,
        "row": 3
      }
    ]
  }
}
```

## Widget Types

| Widget Type | Use Case | Parameters |
|-------------|----------|------------|
| **Radial Gauge** | Primary monitoring, threshold-critical params | value, min, max, thresholds, arc color, needle style |
| **Linear Bar** | Level indicators (DEF, fuel, DPF soot) | value, min, max, fill color, orientation |
| **Digital Readout** | Precise numeric values | value, unit, decimal places, font size, color logic |
| **Sparkline** | Trend at a glance (10-min history) | paramHistory, color, height, fill |
| **Progress Ring** | Percentage-based params | value, max, color, label |
| **Status Indicator** | Binary or tri-state status | value, states map, icon |
| **Mini Chart** | Small line chart with configurable range | param, timeRange, interactive |
| **AI Annotation** | Real-time AI context text | refreshInterval, model (flash for speed) |
| **Stat Card** | Grouped stats (MPG + gear + hours) | params array, layout |

## Prebuilt Dashboard Templates

| Template | Focus | Key Widgets |
|----------|-------|-------------|
| **Daily Driver** | Balanced overview | Boost, RPM, Coolant, Trans, MPG, Fuel Level, Speed, EGT |
| **Towing Heavy** | Temp-critical monitoring | EGT (large), Trans Temp (large), Coolant, Oil Temp, Load %, Grade Estimate |
| **Mountain Run** | Altitude + temps | EGT, Coolant, Altitude, Boost, Trans Temp, Estimated HP |
| **Track Day** | Performance metrics | Boost (large), RPM (large), EGT, Estimated HP, Turbo Speed, Throttle Position |
| **Economy Cruise** | Fuel efficiency | Instant MPG (large), Trip MPG, Fuel Rate, Engine Load, Speed, Fuel Level |
| **Winter Cold Start** | Cold weather monitoring | Coolant, Oil Temp, Intake Temp, Oil Pressure, Battery Voltage, Block Heater Timer |
| **Break-In Mode** | New engine limits | RPM (with 3000 RPM limit alert), Oil Pressure, Coolant, Load %, Trip Odometer |
| **DPF Watch** | Emissions system | DPF Soot (large), Regen Status, EGT, DEF Level, DEF Temp, Regen Counter |

## AI Dashboard Generation Flow

1. User opens dashboard editor and taps **"Generate with AI"**
2. User types natural language description:
   > *"I want a dashboard for monitoring my truck while towing a 12,000 lb trailer through the Rockies"*
3. App calls **Gemini 3.1 Pro** via Firebase AI Logic client SDK with the prompt + full PID definitions list as context
4. Gemini returns a structured dashboard JSON matching the schema above
5. App renders a **preview** of the generated dashboard. User can accept, modify, or regenerate.
6. Dashboard saved to Firestore under `vehicles/{vehicleId}/dashboards/{dashboardId}`

## Dashboard Sources

| Source | Description |
|--------|------------|
| `user` | Manually created by user in dashboard editor |
| `ai_generated` | Created by Gemini from natural language prompt |
| `template` | Installed from prebuilt template library |
| `community` | Installed from community-shared dashboards |

## Community Dashboards (Post-Launch)

- Browse dashboards shared by other Cummins owners
- Install with one tap
- Rate and review
- Stored in global `communityDashboards/{dashboardId}` collection

## Dashboard Widget System

- **Pluggable** — new widget types register in a factory, instantly available everywhere
- Dashboard editor: add/remove/reposition widgets, save/load
- Landscape compact strip mode supported
