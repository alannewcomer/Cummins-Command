# Cummins Command V2 — App Screens

> 6 tabs + Data Explorer as drill-through. Every screen is AI-first.

## Navigation Structure

- Tab 1: **Command Center** (Home)
- Tab 2: **Data Explorer**
- Tab 3: **Drive History**
- Tab 4: **AI Insights**
- Tab 5: **Maintenance Log**
- Tab 6: **Settings & Vehicles**

---

## Screen 1 — Command Center (Home)

**NOT a gauge grid. An AI-driven command center.**

### Top: AI Status Strip
- Persistent horizontal strip at the top
- Updates every few seconds using **Gemini 2.5 Flash** for speed
- Examples:
  - *"All systems nominal. Engine running 3°F cooler than baseline. Fuel economy: excellent."*
  - *"Trans temp climbing — 220°F and rising. Consider downshift if towing."*
  - *"DPF soot load at 78%. Regen likely within 20 miles."*

### Middle: Active Dashboard (Customizable)
The gauge grid is now one of many possible layouts. User selects or creates their active dashboard.

**Default**: 6 radial gauges (boost, EGT, RPM, coolant, trans, oil pressure) with scrollable secondary strip below.

**Switchable to**:
- **Prebuilt Templates**: Daily Driver, Towing, Mountain, Track, Economy, Winter, Break-In, DPF Watch
- **Custom Dashboards**: User opens editor, picks any PID, chooses widget type, sets size/position/thresholds
- **AI-Generated Dashboards**: Natural language → Gemini 3.1 Pro → dashboard config JSON
- **Community Dashboards**: Browse/install dashboards shared by other users

### Bottom: Stats Bar + Quick Actions
- Instant MPG, Trip MPG, Gear Estimate, Engine Hours
- Quick actions: Start/Stop Recording, Switch Dashboard, Open Data Explorer

### Expanded Gauge View
Tap any gauge to expand full-screen with:
- Large gauge + current value
- Session min/max + historical average
- 10-minute sparkline
- AI annotation (*"This reading is 8% above your 30-day average"*)
- Button to open parameter in Data Explorer

---

## Screen 2 — Data Explorer

**THE SINGLE BIGGEST ADDITION IN V2.** Professional-grade time-series data exploration built into a mobile app.

### Core Features

| Feature | Description |
|---------|------------|
| **Parameter Picker** | Full searchable list of every captured OBD2 and J1939 parameter. Shows current value, unit, normal range, AI context. Select one or more to plot. |
| **Time Range Selector** | Presets: This Drive, Last Drive, 7 Days, 30 Days, 90 Days, 1 Year, All Time. Plus custom date/time range with drag handles. |
| **Multi-Overlay** | Plot up to 6 parameters on same chart with independent Y-axes. Each gets its own color and scale. |
| **Pinch-to-Zoom** | Zoom to individual 500ms datapoints or out to months of trend data. GPU-accelerated with Syncfusion. |
| **Crosshair Inspection** | Long press → exact value for every plotted parameter at that timestamp. Snap to nearest datapoint. |
| **Trackball** | Touch and drag → tooltip follows finger showing all parameter values at that point. |
| **Statistical Analysis** | Min, max, mean, median, std dev, percentile distribution (P5, P25, P50, P75, P95), rate of change, trend line slope. |
| **Annotations** | DPF regen events, alert threshold crossings, drive start/end, AI-flagged anomalies as vertical lines/markers. |
| **Compare Periods** | Side-by-side or overlay comparison of same parameter across two time ranges. |
| **AI Analysis** | "Ask Gemini about this data" button → sends visible chart context to Gemini 3.1 Pro. |
| **Export** | PNG image, CSV data, share to social media or forums. |

### Implementation
Built on **Syncfusion Flutter Charts** (`SfCartesianChart`):
- Real-time update, zoom/pan (pinch, selection, double-tap)
- Crosshair with axis tooltips, trackball with customizable markers
- Multiple Y-axes for overlay, fast rendering of 100,000+ datapoints
- Dynamic series addition/removal
- Reads directly from Firestore datapoints subcollection with pagination

---

## Screen 3 — Drive History

Chronological list of all recorded drives with AI-enriched detail.

### Drive Card Shows:
- Date, duration, distance, avg MPG
- Health score ring (0-100)
- Max boost, max EGT
- Tags (towing, commute, mountain, track)
- One-line AI summary

### Interactions:
- **Filter** by date range, health score, tags, or anomaly presence
- **Tap** → Full detail with summary stats, parameter charts (Data Explorer components), AI analysis card, DPF regen markers
- **Long-press** → Compare with another drive side-by-side

---

## Screen 4 — AI Insights

The AI brain of the app. Sub-sections:

### Today's Briefing
- Auto-generated after each drive upload
- AI summary of recent activity, truck health, and attention items
- Written in plain English, not technical jargon

### Health Dashboard
- Overall health score 0–100
- Sub-scores: Engine, Transmission, Emissions, Fuel System, Cooling System, Electrical
- Each sub-score shows what's affecting it and trend direction
- Health history chart showing score over time

### Predictive Maintenance
- AI-generated predictions based on trend analysis across all historical data
- Each prediction: what, why, confidence score, recommended action, estimated timeline
- User can mark as resolved or dismissed
- Examples:
  - *"DPF regen frequency increased 40% over 30 days — consider cleaning"*
  - *"Oil temp trending up 2°F per week for 8 weeks — check oil level and condition"*

### Ask Gemini (Chat)
- Full conversational AI chat with complete truck context injected
- Gemini knows your truck, your drives, your data
- Ask anything:
  - *"Why did my MPG drop last week?"*
  - *"Is 1,340°F EGT safe for sustained mountain towing?"*
  - *"Compare my truck's performance before and after the intake mod"*
- Conversation history saved

### Range Analysis
- Select any date range
- AI sends aggregated data to Gemini 3.1 Pro via Cloud Function (long-running job with progress updates)
- Returns deep analysis: patterns, concerns, recommendations, comparisons to baseline

---

## Screen 5 — Maintenance Log

Complete maintenance tracking with AI-assisted scheduling.

- Upcoming items with progress bars
- Color-coded status: green / amber / red / overdue
- AI predictions integrated alongside manual entries
- Full service history timeline
- Cost tracking per item and cumulative
- Categories for every Cummins service item
- Export as PDF
- Quick-add for common services

---

## Screen 6 — Settings & Vehicles

### Vehicles Tab (Primary)
- List of all vehicles (owned and shared)
- Active vehicle indicator
- Per vehicle: full profile, mod history, baseline data
- **Add Vehicle**: Enter VIN → auto-decode (year, make, model, engine, factory specs) or manual entry
- **Share Vehicle**: Invite by email with granular permissions. Generate share link with short code. Manage/revoke access.
- **Switch Vehicle**: Also accessible from header on any screen. Tap vehicle name → vehicle picker.

### Other Settings Tabs
- OBD Connection
- Alert Thresholds
- Display Preferences
- Data Management
- AI Settings (model selection via Remote Config, analysis depth, auto-analyze toggle, thinking budget)
