# Cummins Command V2 — PID & Data Capture Definitions

> Every captured parameter is surfaceable in Data Explorer, usable in custom dashboards, and queryable by AI.

## Standard OBD2 PIDs (Mode 01)

| PID | Parameter | Unit | Poll Rate | Data Explorer |
|-----|-----------|------|-----------|---------------|
| `0x05` | Coolant Temperature | °F | 500ms | Yes |
| `0x0B` | Intake Manifold Pressure | kPa | 1000ms | Yes |
| `0x0C` | Engine RPM | rpm | 500ms | Yes |
| `0x0D` | Vehicle Speed | mph | 500ms | Yes |
| `0x0F` | Intake Air Temperature | °F | 2000ms | Yes |
| `0x10` | MAF Air Flow Rate | g/s | 1000ms | Yes |
| `0x11` | Throttle Position | % | 500ms | Yes |
| `0x1F` | Run Time Since Start | sec | 5000ms | Yes |
| `0x2F` | Fuel Tank Level | % | 5000ms | Yes |
| `0x33` | Barometric Pressure | kPa | 5000ms | Yes |
| `0x42` | Control Module Voltage | V | 5000ms | Yes |
| `0x46` | Ambient Air Temperature | °F | 5000ms | Yes |
| `0x5C` | Oil Temperature | °F | 1000ms | Yes |
| `0x5E` | Fuel Rate | gph | 1000ms | Yes |

## J1939 Cummins-Specific SPNs

| SPN | Parameter | Unit | Poll Rate | Critical |
|-----|-----------|------|-----------|----------|
| **102** | Boost Pressure | PSI | 500ms | **YES** |
| **110** | Coolant Temperature | °F | 500ms | **YES** |
| 174 | Fuel Temperature | °F | 2000ms | |
| **175** | Oil Temperature | °F | 1000ms | **YES** |
| **190** | Engine Speed | rpm | 500ms | **YES** |
| 513 | Actual Gear Ratio | ratio | 1000ms | |
| **1127** | Turbocharger Speed | rpm | 1000ms | **YES** |
| **1176** | Transmission Oil Temperature | °F | 500ms | **YES** |
| **2630** | DPF Soot Load | % | 2000ms | **YES** |
| **2659** | DPF Regen Status | enum | 2000ms | **YES** |
| **3226** | EGT (Exhaust Gas Temp) | °F | 500ms | **YES** |
| **3464** | DEF Tank Level | % | 5000ms | **YES** |
| 3563 | DEF Temperature | °F | 5000ms | |
| **157** | Fuel Rail Pressure | PSI | 1000ms | **YES** |
| **100** | Oil Pressure | PSI | 500ms | **YES** |
| **92** | Engine Load | % | 500ms | **YES** |
| 183 | Fuel Rate | gph | 1000ms | |
| 245 | Total Odometer | mi | 5000ms | |
| 247 | Total Engine Hours | hrs | 5000ms | |
| 84 | Vehicle Speed | mph | 500ms | |
| 108 | Barometric Pressure | PSI | 5000ms | |

## Poll Rate Tiers

| Tier | Interval | Parameters |
|------|----------|------------|
| **Fast** | 500ms | RPM, speed, boost, EGT, coolant, trans temp, oil pressure, engine load, throttle |
| **Medium** | 1000ms | Oil temp, MAF, fuel rate, turbo speed, gear ratio, rail pressure, intake manifold |
| **Slow** | 2000ms | Intake air temp, fuel temp, DPF soot, DPF regen status |
| **Background** | 5000ms | Fuel tank level, barometric, ambient temp, voltage, odometer, engine hours, DEF level, DEF temp, run time |

## Calculated Parameters (Derived at Capture Time)

| Parameter | Formula/Source | Unit |
|-----------|---------------|------|
| Instant MPG | Derived from speed + fuel rate | mpg |
| Estimated Gear | Derived from speed + RPM + gear ratios | gear number |
| Estimated HP | Derived from acceleration + boost + RPM | hp |
| Estimated Torque | Derived from load + RPM | lb-ft |

## GPS Data (Captured Alongside PIDs)

| Field | Unit |
|-------|------|
| Latitude | degrees |
| Longitude | degrees |
| Altitude | feet |
| GPS Speed | mph |
| Heading | degrees |

## Key Design Principle

- PID system is **config-driven** — new PIDs are added to a config file, app automatically supports them
- `pidDefinitions/{pidId}` global collection holds master list with display names, units, formulas, normal ranges, and AI context strings
- EVERY parameter is available in: Data Explorer, custom dashboards, AI queries, and export
- **Nothing is captured without being made available to the user**
