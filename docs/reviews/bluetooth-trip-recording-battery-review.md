# Bluetooth + Trip Recording + Battery Deep Dive Review

**Date:** 2026-02-23
**Scope:** OBDLink MX+ <-> Phone <-> Truck connection architecture, trip recording reliability, and battery drain prevention

---

## Executive Summary

The current architecture is **well-designed** for the core goal of recording every trip without draining the truck battery. The three-phase sleep reconnect strategy, engine state detection, and automatic trip recording form a solid foundation. However, there are **several gaps and risks** that could cause missed trips or unexpected battery drain in real-world scenarios. This review identifies 5 critical issues and 8 recommendations.

---

## 1. Connection Architecture (Truck <-> MX+ <-> Phone)

### How It Works Today

```
┌──────────────┐    OBD-II Port     ┌──────────────┐   BT Classic    ┌──────────────┐
│  2026 Ram    │◄──(CAN 29-bit)────►│  OBDLink MX+ │◄──(RFCOMM)────►│  Phone App   │
│  6.7L Cummins│    500k baud       │  (62-69 mA)  │   115200 baud  │  (Flutter)   │
└──────────────┘                    └──────────────┘                 └──────────────┘
```

**Physical layer:**
- MX+ plugs into the truck's OBD-II port (always powered on pin 16)
- Communication: CAN 29-bit 500k (ISO 15765-4), confirmed working on 2026 Ram 2500
- Phone connects via **Bluetooth Classic v3.0** (NOT BLE) over RFCOMM/SPP

**Key files:**
- `lib/services/bluetooth_service.dart` - RFCOMM connection management
- `lib/services/obd_service.dart` - OBD protocol and polling engine
- `lib/providers/live_data_provider.dart` - Lifecycle orchestrator

### Assessment: GOOD

The Bluetooth Classic choice is correct for the MX+. The `flutter_bluetooth_classic_serial` package is the right tool. Connection flow (scan paired devices -> connect -> wait for RFCOMM socket -> start data streams) is clean and well-structured.

---

## 2. Trip Recording Reliability

### How Trips Are Detected and Recorded

**Trip Start (auto-detect):**
1. OBD polling is active, receiving live data
2. Vehicle speed > 5 mph for 5 consecutive seconds
3. `DriveRecorder.startRecording()` fires automatically
4. Creates Firestore document + opens local timeseries writer

**Trip Start (engine-state trigger):**
1. `obdLifecycleProvider` watches `engineStateStream`
2. When `EngineState.running` is detected AND RPM > 50
3. `_autoStartRecording()` fires immediately (no speed requirement)

**Trip End:**
1. Speed < 5 mph for 5 minutes (idle timeout), OR
2. Engine enters `EngineState.accessory` (key-off detected, immediate stop)

**Data flow during recording:**
- OBD data stream -> derived calculations (instantMPG, gear) -> accumulate stats -> append to TimeseriesWriter -> gzip'd column-oriented JSON on disk -> upload to Firebase Storage after trip ends

### Assessment: MOSTLY GOOD, with gaps

**What works well:**
- Dual trip-start triggers (speed threshold + engine state) provide redundancy
- Immediate stop on engine-off (accessory state) is smart -- doesn't wait 5 minutes
- Orphan drive recovery handles app crashes gracefully
- Local file + background upload pattern is resilient
- Running statistics (min/max/avg) computed in-memory, not from raw points

### CRITICAL ISSUE #1: Race condition between auto-start triggers

In `live_data_provider.dart:225-244`, `_autoStartRecording()` has an RPM gate:
```dart
final rpm = obdService.liveData['rpm'] ?? obdService.liveData['engineSpeed'];
if (rpm == null || rpm < AppConstants.engineOffRpmThreshold) return;
```

And in `drive_recorder.dart:552-564`, auto-detect has a speed gate:
```dart
if (speed > AppConstants.driveStartSpeedThreshold) { // 5 mph
    _speedAboveThresholdSince ??= DateTime.now();
```

**The problem:** When `EngineState.running` fires, the engine just started -- RPM is above threshold but speed is 0. So `_autoStartRecording()` starts recording immediately (good). But if that call happens *before* `enableAutoDetect()` is called, or if the provider rebuilds and the recorder gets a new instance, the speed-based auto-detect might try to start a second recording or not be enabled at all.

**Risk level:** LOW -- the `if (_recording) return _driveId;` guard in `startRecording()` prevents double-starts. But worth verifying the provider lifecycle.

### CRITICAL ISSUE #2: Trip missed if app is killed during Phase C reconnect

The three-phase sleep reconnect relies on the foreground service keeping the process alive. But:
- Android can still kill foreground services under memory pressure
- Users might force-stop the app
- Phone restart clears the foreground service

If the app is killed during Phase C (35+ minutes after engine off), and the user starts the truck again:
1. MX+ wakes on CAN bus activity
2. MX+ Bluetooth radio turns on
3. **No app is running to connect**
4. Trip is completely missed until user manually opens the app

**Risk level:** HIGH -- this is the most likely scenario for missed trips (overnight parking, next-morning commute).

**Current mitigation:** `tryAutoConnect()` on app resume. But this requires the user to open the app.

### CRITICAL ISSUE #3: 5-minute idle timeout may truncate short trips

If you stop at a long red light, fast food drive-through, or gas station, and stay stopped for 5+ minutes:
- Recording stops
- When you start moving again, a **new** trip is created
- Original trip's distance/fuel stats are incomplete

The engine state detection handles this better (engine stays running at a light), but if the MX+ reports brief RPM dropouts (which happens on some vehicles during auto start-stop), the system could misinterpret this.

**Risk level:** MEDIUM -- the 2026 Cummins doesn't have auto start-stop, but fuel-saving idle shutoffs could trigger this.

---

## 3. Battery Drain Analysis

### Truck Battery (12V)

**MX+ Power Consumption:**
| State | Current Draw | Source |
|-------|-------------|--------|
| Active (communicating) | 62-69 mA | OBDLink specs |
| Idle (BT connected, no queries) | ~62 mA | OBDLink specs |
| BatterySaver Sleep | 2 mA | OBDLink specs |

**CRITICAL: CAN bus wake-keeping.** When the MX+ is actively sending OBD-II queries, it keeps the truck's ECU and CAN modules awake. This can draw **hundreds of milliamps** from the truck battery beyond just the MX+'s 62 mA. The total parasitic draw could be 200-500+ mA if the app stays connected and polling.

**Current code mitigation (GOOD):**
1. Engine off detection -> accessory mode polling (RPM + voltage only, 2s interval)
2. Accessory -> off detection -> `AT LP` command + BT disconnect
3. Three-phase reconnect with 30-minute quiet period for BatterySaver

**Assessment: WELL-DESIGNED**

The three-phase strategy is thoughtful:
- **Phase A (0-5 min, every 30s):** Catches quick restarts. Each attempt wakes the MX+ briefly (~200ms), negligible drain.
- **Phase B (5-35 min, QUIET):** Lets MX+ BatterySaver fully power down the BT radio. This is the key insight -- the MX+ needs ~30 min of no BT activity to reach deep sleep (2 mA).
- **Phase C (35+ min, every 60s):** MX+ BT radio is OFF, so connection attempts instant-fail with zero impact on truck battery.

**Loop detection** (skip Phase A if two disconnects within 5 min) prevents the pathological case of repeatedly waking the adapter.

### CRITICAL ISSUE #4: Accessory mode keeps CAN bus alive

When in `EngineState.accessory`, the code still polls RPM + voltage every 2 seconds:

```dart
// obd_service.dart:622-651
Future<void> _pollAccessoryMode() async {
    final rpmPid = PidRegistry.get('rpm');
    await requestPid(rpmPid);  // Sends 010C on CAN bus
    await _readAdapterVoltage(); // AT RV (adapter-only, no CAN)
}
```

**The RPM query (`010C`) keeps the CAN bus awake.** The voltage read (`AT RV`) is safe -- it reads the adapter's voltage pin without touching CAN. But the RPM query wakes/keeps-alive the ECU.

For the fast alternator-off detection path (10 seconds), this is fine -- only a few RPM queries before transition to off. But for the fallback low-voltage path (30 seconds) or the ECU timeout path (30 seconds), we're sending CAN queries for up to 30 seconds unnecessarily.

**Risk level:** MEDIUM -- 30 seconds at 62+ mA is negligible for a truck battery (0.5 mAh), but it delays the MX+ BatterySaver countdown.

### CRITICAL ISSUE #5: `AT LP` may not work as expected

From the code (`bluetooth_service.dart:415-427`):
```dart
try {
    await sendCommand('AT LP', timeout: const Duration(seconds: 1));
} on TimeoutException {
    diag.debug('BT-SVC', 'AT LP timeout (expected — adapter is sleeping)');
}
```

The `AT LP` command puts the ELM327 into low-power mode. But:
- The OBDLink MX+ has its own BatterySaver that operates **independently** of `AT LP`
- `AT LP` puts the ELM327 chip to sleep, but the MX+'s BT module may stay powered
- The MX+'s BatterySaver needs both: (a) no CAN activity AND (b) no BT connection for ~10 minutes to start its own sleep sequence

**The real sleep trigger is disconnecting Bluetooth**, which the code does correctly. The `AT LP` is a nice-to-have but not critical.

**Risk level:** LOW -- the BT disconnect is the important part, and that works correctly.

### Phone Battery

**Current approach:**
- Foreground service (`flutter_background_service`) keeps process alive
- Shows persistent notification
- Phase C polling uses `Timer.periodic(60s)` -- minimal CPU wake

**Assessment: ACCEPTABLE**

The foreground service approach is standard for Android. The 60-second timer is reasonable. The main phone battery concern would be:
- GPS tracking during active recording (handled by `LocationService`)
- BT Classic RFCOMM overhead during active polling (~500ms cycle)

Neither is excessive for the use case.

---

## 4. OBDLink MX+ Specifics (from research)

### Key Facts
- **Bluetooth Classic v3.0** (Class 2), NOT BLE -- range ~260 feet / 80 meters
- **BatterySaver Technology:** 2 mA sleep mode, wakes on CAN activity or BT connection
- **Sleep timeline:** ~10 minutes after BT disconnect to begin sleep, ~30 minutes to fully power down BT radio
- **Safe to leave plugged in:** At 2 mA, would take 1,000+ days to drain a 60 Ah battery
- **CAN bus keep-alive warning:** If app stays connected and polling, vehicle modules stay awake (potentially hundreds of mA total draw)

### MX+ vs CX Consideration
The OBDLink CX (BLE 5.1) offers:
- Lower power (55 mA active, <2 mA sleep)
- Better iOS background support (BLE has native iOS background modes)
- Ultra-slim form factor

But lacks:
- SW-CAN / MS-CAN support (not needed for Cummins)
- Raw data speed (BLE is ~3x slower than Classic)
- Third-party app compatibility

**For this specific use case (Cummins diesel monitoring), the MX+ is the better choice** due to its higher data throughput needed for the 34+ PIDs being polled at 500ms intervals.

---

## 5. Recommendations

### R1: Add a boot/restart auto-connect mechanism (addresses Critical Issue #2)

**Problem:** If the app is killed, trips are missed until user manually opens the app.

**Options:**
- **Android:** Use `WorkManager` with a periodic task (every 15 min) that checks if BT adapter is discoverable. If found, launch the foreground service and connect.
- **Android:** Register a `BroadcastReceiver` for `BluetoothDevice.ACTION_ACL_CONNECTED` -- Android will notify when the paired MX+ becomes available.
- **Boot receiver:** Register for `BOOT_COMPLETED` to restart the foreground service after phone restart.

**Recommendation:** The `BroadcastReceiver` approach is ideal -- zero battery cost, instant trigger when MX+ wakes up. This would close the biggest gap in "record every trip."

### R2: Stop CAN polling in accessory mode, use AT RV only (addresses Critical Issue #4)

Once in accessory mode, switch to:
```dart
Future<void> _pollAccessoryMode() async {
    // Only read adapter voltage (no CAN traffic)
    await _readAdapterVoltage();

    // If voltage jumps above alternatorChargingVoltage, engine restarted
    if (_lastVoltageReading != null &&
        _lastVoltageReading! > AppConstants.alternatorChargingVoltage) {
        // Engine restarted -- try RPM to confirm
        await requestPid(rpmPid);
    }
}
```

This eliminates CAN bus wake-keeping during the accessory period, letting the truck's modules sleep sooner and reducing total parasitic draw.

### R3: Merge short trips with a "trip continuation" window

When a trip ends due to idle timeout (not engine off), keep a 2-3 minute window where if speed exceeds the threshold again, the existing trip is **resumed** rather than creating a new one. This handles gas stations, drive-throughs, and traffic stops.

### R4: Add a "trip guarantee" watchdog

Create a secondary check that runs on app launch:
1. Query the MX+ for engine runtime (PID `011F` or `017F`)
2. Compare with the last known runtime from the previous trip
3. If delta > 0 and no trip was recorded for that period, create a "gap alert" so the user knows a trip was missed

### R5: Request battery optimization exemption on Android

Use the `disable_battery_optimization` package to prompt the user to exempt the app from battery optimization. This significantly reduces the chance of the OS killing the foreground service. Add this to the onboarding flow after BT pairing.

### R6: Consider reducing Phase C interval based on time-of-day

Phase C polls every 60 seconds forever. At 3 AM, the truck is unlikely to start. Consider:
- Daytime (6 AM - 10 PM): 60-second interval (current)
- Nighttime (10 PM - 6 AM): 5-minute interval or pause entirely
- Or let the user set their typical driving schedule

This is a minor optimization but shows attention to battery efficiency.

### R7: Add telemetry for connection reliability

Track and report (anonymized) metrics:
- Trips successfully auto-started vs. manually started
- Phase A/B/C reconnect success rates
- Orphaned drive frequency
- Average time between engine start and first data point

This data will reveal how often trips are actually being missed in the field.

### R8: Implement J1939 passive monitoring for richer trip data

Currently blocked: J1939 Request PGN returns "NO DATA" because the 2026 Ram's CAN gateway blocks request-response J1939. But J1939 data is **broadcast** on the bus. Using `ATMA` (Monitor All) or `ATCRA` (CAN filter) for passive listening would unlock:
- Per-cylinder EGT (vs single OBD2 EGT)
- Oil temp/pressure
- Transmission temp
- Turbo speed
- DPF soot load
- DEF level/dosing
- NOx sensors
- True odometer and engine hours

This is an enhancement, not a bug fix, but would significantly increase the value of recorded trip data.

---

## 6. Summary Scorecard

| Area | Rating | Notes |
|------|--------|-------|
| BT Connection Architecture | **A** | Clean RFCOMM implementation, proper state management |
| Trip Auto-Detection | **B+** | Dual triggers good, but gap if app is killed |
| Trip Recording Fidelity | **A-** | Column-oriented timeseries, orphan recovery, 60+ params |
| Truck Battery Protection | **A-** | Three-phase sleep is excellent, minor CAN wake issue |
| Phone Battery Efficiency | **B+** | Foreground service is standard, could optimize Phase C |
| Reconnect After Engine Off | **B** | Works if app stays alive, fails if app is killed |
| Reconnect After App Kill | **D** | Only works when user manually opens app |
| Data Richness | **B** | 34 OBD2 PIDs working, J1939 blocked by gateway |

### Priority Actions:
1. **HIGH:** R1 - BroadcastReceiver for auto-connect (fixes the "missed trip after app kill" gap)
2. **HIGH:** R5 - Battery optimization exemption (keeps foreground service alive)
3. **MEDIUM:** R2 - AT RV only in accessory mode (reduces CAN wake time)
4. **MEDIUM:** R3 - Trip continuation window (prevents trip fragmentation)
5. **LOW:** R4, R6, R7 - Watchdog, time-based Phase C, telemetry (polish)
6. **FUTURE:** R8 - J1939 passive monitoring (major feature)

---

## Appendix: Key Code Locations

| Component | File | Key Functions |
|-----------|------|---------------|
| BT Connection | `bluetooth_service.dart` | `connect()`, `disconnectForSleep()`, `_startSleepReconnect()` |
| Sleep Phases A/B/C | `bluetooth_service.dart:707-794` | `_startPhaseA()`, `_startPhaseB()`, `_startPhaseC()` |
| Engine State Machine | `obd_service.dart:682-766` | `_updateEngineState()` |
| Accessory Polling | `obd_service.dart:622-651` | `_pollAccessoryMode()` |
| Trip Auto-Detect | `drive_recorder.dart:545-579` | `_onDataForAutoDetect()` |
| Trip Recording | `drive_recorder.dart:296-362` | `startRecording()` |
| Trip Finalization | `drive_recorder.dart:368-530` | `stopRecording()` |
| Lifecycle Orchestrator | `live_data_provider.dart:116-219` | `obdLifecycleProvider` |
| Auto-Start Recording | `live_data_provider.dart:225-244` | `_autoStartRecording()` |
| Background Service | `background_service.dart` | `initializeBackgroundService()` |
| Constants/Tuning | `constants.dart` | All timing thresholds |
