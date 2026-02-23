# Cummins Command V2 — Design System

## Color Palette

| Token | Value | Usage |
|-------|-------|-------|
| **Background** | `#07070F` | Near black — primary background |
| **Surface** | `#12121E` | Card/panel background |
| **Surface Border** | `#1E1E32` | Card borders, dividers |
| **Primary Accent** | `#FF6B00` | Cummins orange — primary actions, highlights |
| **Data Accent** | `#00AAFF` | Electric blue — data values, charts, links |

## Typography

| Font | Usage | Package |
|------|-------|---------|
| **Orbitron** | Display text, data values, gauge readings | `google_fonts` |
| **JetBrains Mono** | Labels, technical text, PID names, units | `google_fonts` |
| **Inter** | Body text, descriptions, AI summaries | `google_fonts` |

### Hierarchy
- Hero/display: Orbitron Bold
- Section headers: Orbitron Medium
- Data values: Orbitron (monospaced feel for numbers)
- Technical labels: JetBrains Mono
- Body/descriptions: Inter Regular
- AI text: Inter with orange diamond icon prefix

## Gauge Styling

- Dark face background
- Glowing arc (color based on threshold state)
- Animated needle with smooth transitions
- Threshold colors: green → amber → red

## Transitions & Animation

- **Duration**: 300ms ease curves
- **Rendering**: GPU-accelerated
- Page transitions, gauge updates, chart interactions all animated
- 60fps target on dashboard

## Haptic Feedback

| Event | Haptic |
|-------|--------|
| Value change | Light impact |
| Warning threshold | Medium impact |
| Critical alert | Heavy impact |

## AI Element Styling

All AI-generated content is visually marked:
- Orange diamond icon prefix
- **"GEMINI 3.1 PRO"** badge
- Distinct card styling to differentiate AI content from raw data

## Screen Layout Patterns

### Command Center
```
┌─────────────────────────────────┐
│  AI Status Strip (Flash)         │  ← Gemini 2.5 Flash, updates every few seconds
├─────────────────────────────────┤
│                                  │
│    Active Dashboard              │  ← Configurable gauge grid
│    (Radial/Linear/Digital/       │
│     Sparkline widgets)           │
│                                  │
├─────────────────────────────────┤
│  Stats Bar + Quick Actions       │  ← MPG, Gear, Hours, Record btn
└─────────────────────────────────┘
```

### Expanded Gauge View
```
┌─────────────────────────────────┐
│         Large Gauge              │
│     ┌───────────────────┐       │
│     │   Current: 28 PSI  │       │
│     │   Min: 5  Max: 42  │       │
│     │   Avg (30d): 22    │       │
│     └───────────────────┘       │
│  ┌──────────────────────────┐   │
│  │  10-min Sparkline         │   │
│  └──────────────────────────┘   │
│  ┌──────────────────────────┐   │
│  │ ◆ AI: "8% above 30-day   │   │
│  │   average"                │   │
│  └──────────────────────────┘   │
│  [ Open in Data Explorer ]      │
└─────────────────────────────────┘
```

## Responsive Modes

- **Portrait**: Full dashboard grid
- **Landscape**: Compact strip mode with essential gauges in a horizontal bar
