# Cummins Command V2 — Default Alert Thresholds (6.7L Cummins)

## Threshold Table

| Parameter | Normal Range | Warning (Amber) | Critical (Red) | AI Context |
|-----------|-------------|-----------------|-----------------|------------|
| **EGT** | 400–900°F | > 1,100°F | > 1,400°F | Sustained >1200°F for >5min = downshift recommendation |
| **Coolant Temp** | 180–210°F | > 220°F | > 240°F | Rising trend of >1°F/week for 4+ weeks = cooling system inspection |
| **Trans Temp** | 150–210°F | > 220°F | > 250°F | Spike >230°F during tow = check fluid condition |
| **Boost PSI** | 5–35 PSI | > 35 PSI | > 50 PSI | Boost drop >15% from baseline = check turbo/intercooler |
| **Oil Pressure** | 40–75 PSI | < 25 PSI | < 15 PSI | Low idle pressure + rising oil temp = check level immediately |
| **Oil Temp** | 200–230°F | > 240°F | > 260°F | Rising trend + stable ambient = oil degradation likely |
| **DPF Soot Load** | 0–60% | > 80% | > 95% | Regen frequency increase >30% in 30 days = cleaning recommended |
| **DEF Level** | 20–100% | < 15% | < 10% | Derating imminent at <5% — immediate fill required |
| **Fuel Rail Pressure** | 5–29 kPSI | < 4 kPSI / > 28 kPSI | < 3 kPSI / > 29 kPSI | Low pressure + hard start = fuel filter or CP3 pump check |
| **Turbo Speed** | 40–130k RPM | > 135k RPM | > 145k RPM | Overspin risk at >145k — check wastegate |
| **Coolant Level** | Full | Low | Critical | Low coolant + rising temp = stop and inspect immediately |

## Alert System Behavior

### Visual
- **Green**: Normal range — no indicator
- **Amber**: Warning threshold crossed — gauge changes to amber, value highlighted
- **Red**: Critical threshold crossed — gauge changes to red, prominent alert overlay

### Haptic Feedback
- **Light impact**: Value change notifications
- **Medium impact**: Warning threshold crossed
- **Heavy impact**: Critical threshold crossed

### Push Notifications (FCM)
- Critical alerts sent via Firebase Cloud Messaging even when app is backgrounded
- AI predictions (e.g., "DPF regen likely within 20 miles") sent as notifications
- Maintenance reminders

### AI Integration
Every threshold crossing is:
1. Logged as an annotation in the Data Explorer
2. Included in the drive's AI analysis context
3. Fed into predictive maintenance trend analysis
4. Displayed with plain-English AI context explaining what it means

## Configurability
- Every parameter threshold is user-configurable in Settings > Alert Thresholds
- Defaults optimized for stock 6.7L Cummins
- AI can suggest threshold adjustments based on mod history
