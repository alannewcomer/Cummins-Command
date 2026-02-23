# OBD Polling Issues — From Logs 2026-02-22

Session: 20:53:12 - 20:56:08 (~3 min), engine running (idle 650-770 RPM), parked.
Status after ATSH header fix: **12/22 OBD2 PIDs working, 0/20+ J1939 PIDs working.**
11 sensors recording to Firestore, 41 sensors never recorded.

## ECU Info (from protocol detection)

Two ECUs responding on CAN 29-bit 500k (ATSP7):
- **ECU 0x10** — responds to all PIDs, likely ECM (Cummins engine controller)
- **ECU 0x18** — responds to most PIDs, likely body/instrument controller

```
Probe 0100 on ATSP7 raw:
  18DAF11806410098180001    ← ECU 0x10: bitmap 98180001
  18DAF110064100981B0013    ← ECU 0x18: bitmap 981B0013 (note: different!)
```

### Supported PID bitmap (merged from both ECUs):
```
0x01-0x20: 0x01, 0x04, 0x05, 0x0C, 0x0D, 0x20
0x21-0x40: 0x21, 0x2F, 0x30, 0x31, 0x33, 0x40
0x41-0x60: 0x42, 0x49, 0x60
0x61-0x80: 0x61, 0x62, 0x63, 0x64, 0x65, 0x69, 0x6B, 0x6C, 0x6D,
           0x70, 0x71, 0x73, 0x74, 0x75, 0x77, 0x78, 0x7A, 0x7F, 0x80
Total: 34 supported PIDs
```

### PIDs we poll that are NOT in bitmap (tried anyway):
```
intakeManifoldPressure(0x0B), intakeTemp(0x0F), maf(0x10), throttlePos(0x11),
runTime(0x1F), ambientTemp(0x46), oilTempObd(0x5C), fuelRateObd(0x5E)
```
Of these, intakeTemp(0x0F), maf(0x10), runTime(0x1F), ambientTemp(0x46) WORK despite not being in bitmap.

## Working PIDs — Raw Responses

All 12 working PIDs with their first raw CAN frames:

```
engineLoadObd2  cmd=0104  raw=18DAF11003410400 / 18DAF11803410400       → 0.00%
coolantTemp     cmd=0105  raw=18DAF11803410583 / 18DAF11003410583       → 195.80°F
rpm             cmd=010C  raw=18DAF11004410C0000 / 18DAF11804410C0000   → 0.00 rpm (engine off at start, later 769.75 rpm)
speed           cmd=010D  raw=18DAF11003410D00 / 18DAF11803410D00       → 0.00 mph
maf             cmd=0110  raw=18DAF1100441100000                        → 0.00 g/s (later 25.65)
intakeTemp      cmd=010F  raw=18DAF11003410F66                          → 143.60°F
exhaustBP       cmd=0173  raw=18DAF1100741730126990000                   → 2.94 kPa
runTime         cmd=011F  raw=18DAF11004411F0000                        → 0.00 sec
fuelLevel       cmd=012F  raw=18DAF11003412FC9                          → 78.82%
barometric      cmd=0133  raw=18DAF11003413363                          → 99.00 kPa
batteryVoltage  cmd=0142  raw=18DAF110044142277D / 18DAF1180441422FB3   → 10.11V (WRONG — see Issue 9)
ambientTemp     cmd=0146  raw=18DAF11003414625                          → 26.60°F
```

### CAN frame format (for reference):
```
18DAF110 03 4104 00
│        │  │    └─ data byte(s)
│        │  └────── response header: mode+0x40, PID
│        └───────── PCI byte: single frame, N data bytes
└────────────────── 29-bit CAN ID: 18DA + dest(F1=tester) + src(10=ECU)
```

## Datapoint Stats from Recorded Drive

```
Drive: Z4ZgH5rVsNyV7U5pWSuD | 92 datapoints | 106s | 0.0mi | pendingUpload
Avg sample interval: 1101ms

Sensor               Count  Min       Max       Avg
─────────────────────────────────────────────────────
rpm                  92     0         769.75    560.25
speed                92     0         0         0
coolantTemp          92     179.60    195.80    182.42
intakeTemp           92     107.60    143.60    113.23
maf                  92     0         25.65     20.49
engineLoad           92     0         12.94     6.23
exhaustBackpressure  92     2.94      2.99      2.98
fuelLevel            92     78.82     78.82     78.82
batteryVoltage       92     10.11     14.28     13.59    ← min=wrong ECU, max=right ECU
ambientTemp          92     26.60     26.60     26.60
barometric           92     99        99        99
```

Engine WAS running: RPM peaked at 769.75, avg 560.25 (normal Cummins idle).
Battery voltage swings between 10.11V (wrong ECU) and 14.28V (correct, alternator charging).

---

## Issue 1: J1939 protocol not connecting — ALL diesel-specific sensors missing

**Impact:** CRITICAL — No EGT, boost, trans temp, oil temp/pressure, DPF, DEF, turbo speed, VGT, NOx, odometer, engine hours.

**Log evidence:**
```
20:53:14 info  Probing J1939 via raw CAN on 500k bus...
20:53:15 debug J1939 probe PGN 0xF004 (EEC1) raw: NO DATA
20:53:15 info  J1939 probe: no response on CAN 500k — Will try ATSP A (250k) as fallback
20:53:15 debug J1939 fallback probe (ATSP A) raw: CAN ERROR
20:53:15 info  J1939 not available (no response on 500k or 250k)
20:53:16 info  Protocol detection complete result=obd2 obd2=true j1939=false supportedPids=34
```

**What the probe does:** Sets `ATCAF0` (disable ISO-TP), `ATSH 18 EA 00 F9` (J1939 Request PGN header), sends `04 F0 00` (Request PGN 0xF004 = EEC1).

**Why it fails:** The 2026 Ram Cummins ECU may not respond to J1939 Request PGN frames on the 500k CAN bus. Modern Cummins ECUs **broadcast** J1939 data periodically (EEC1 every 10ms, temperatures every 100ms, etc.) — they don't need to be asked.

**Affected PIDs (20+ J1939 sensors):** boostPressure (SPN 102), oilPressure (SPN 100), oilTemp (SPN 175), transTemp (SPN 1176), turboSpeed (SPN 1127), engineSpeed (SPN 190), egt/egt2/egt3/egt4 (SPN 3226-3229), dpfSootLoad (SPN 2630), dpfRegenStatus (SPN 2659), dpfDiffPressure (SPN 3609), defLevel (SPN 3464), defDosingRate (SPN 3483), vgtPosition (SPN 641), egrPosition (SPN 27), noxPreScr/noxPostScr (SPN 3216/3217), fuelRate (SPN 183), odometer (SPN 245), engineHours (SPN 247), etc.

**Possible fixes:**
1. **Passive monitoring**: Use `ATMA` (Monitor All) or `ATMT xx` to listen for broadcast J1939 frames instead of requesting. Parse CAN IDs with PGN in bits 8-25 of the 29-bit CAN header.
2. **CAN filter**: Use `ATCRA` to set receive address filter for specific PGNs, then `ATMA` to monitor.
3. The engine may need to be running for J1939 broadcasts — test was started with engine off (RPM=0 at 20:53:16), engine came on later.
4. ATSP A `CAN ERROR` confirms 250k baud is wrong for this truck (expected — 2020+ trucks use 500k).

**Code location:** `lib/services/obd_service.dart` lines 292-387 (`_detectProtocol`), J1939 probe section.

---

## Issue 2: `intercoolerOutletTemp` (PID 0x6B) — value filtered as implausible

**Impact:** LOW

**Log evidence:**
```
20:54:33 warn  ✗ intercoolerOutletTemp parse_fail cmd=016B raw=18DAF11007416B0170000000
```

**Raw response breakdown:**
```
18DAF110 07 416B 01 70 00 00 00
│        │  │    │  │
│        │  │    │  └─ bytes 2-5 of data
│        │  │    └──── byte 1: 0x01 (sensor support bitmap)
│        │  └───────── response header (mode 0x41, PID 0x6B)
│        └──────────── PCI: 7 data bytes in single frame
└───────────────────── CAN ID: ECU 0x10 → tester 0xF1
```

**What happens:**
1. PID 0x6B defined with `responseBytes: 1` in `pid_config.dart:300`
2. Parser extracts first data byte: `0x01`
3. `_parseTemp([0x01])` = (1-40)*9/5+32 = **-38.2°F**
4. Filter in `obd_service.dart _parseResponse()`: `pid.unit == '°F' && value <= -38.0` → **rejected**

**Actual data:** PID 0x6B is SAE J1979 extended format: `[A=sensor bitmap] [B,C=temp1] [D,E=temp2]`. The real temperature is in bytes B,C: `0x0170` = 368 decimal. Formula: 368/10 - 40 = -3.2°C = 26.2°F. The `0x01` byte is just a bitmap saying "sensor 1 supported."

**Fix:** Change `responseBytes: 1` → `responseBytes: 3`, write a custom parser that skips byte A and reads B,C as the temperature: `(b[1]*256+b[2])/10 - 40` converted to °F.

**Code location:** `lib/config/pid_config.dart:297-304`

---

## Issue 3: `railPressureCmd` & `railPressureActual` — both use PID 0x6D, both fail

**Impact:** MEDIUM — No rail pressure monitoring

**Log evidence:**
```
20:54:53 warn  ✗ railPressureCmd disabled — stale value evicted cmd=016D reason=parse_fail fails=10
20:54:53 warn  ✗ railPressureActual disabled — stale value evicted cmd=016D reason=parse_fail fails=10
```

**Problem details:**
- Both PIDs defined with `code: 0x6D, responseBytes: 6` in `pid_config.dart:307-322`
- Both send the identical command `016D` — redundant, wastes 2x bus time
- PID 0x6D per SAE J1979: 6 data bytes `[A=status] [B,C=commanded kPa] [D,E=actual kPa] [F=fuel temp]`
- The raw response is NOT captured in the "first occurrence" logs (only the "disabled" message appears)
- Likely the ECU returns fewer than 6 bytes, causing `bytes.length < pid.responseBytes` → null

**Parsers (pid_config.dart:65-68):**
```dart
_parseRailPressureCmd(List<int> b) => b.length >= 3 ? (b[1]*256 + b[2]) * 1.45 : 0;    // bytes B,C
_parseRailPressureActual(List<int> b) => b.length >= 5 ? (b[3]*256 + b[4]) * 1.45 : 0;  // bytes D,E
```

**Fix:**
1. Need to capture the raw response to see actual byte count
2. Merge into a single PID that parses both values from one response
3. If ECU returns <6 bytes, adjust `responseBytes` and parser

**Code location:** `lib/config/pid_config.dart:305-322`

---

## Issue 4: `throttlePos` (PID 0x11) — NO DATA

**Impact:** LOW

**Log evidence:**
```
20:55:00 warn  ✗ throttlePos parse_fail cmd=0111 raw=NO DATA
```

Not in ECU supported PID bitmap. The 6.7L Cummins does not expose throttle position via standard OBD2 PID 0x11. The pedal position is J1939 SPN 91 (Accelerator Pedal Position 1) on PGN 0xF003 (EEC2).

**Fix:** Remove from OBD2 polling. Add SPN 91 to J1939 config once Issue 1 is fixed.

**Code location:** `lib/config/pid_config.dart:231-238`

---

## Issue 5: `intakeManifoldPressure` (PID 0x0B) — NO DATA

**Impact:** LOW

**Log evidence:**
```
20:55:00 warn  ✗ intakeManifoldPressure parse_fail cmd=010B raw=NO DATA
```

Not in ECU supported PID bitmap. Cummins provides boost via J1939 SPN 102 instead.

**Fix:** Remove from OBD2 polling. Rely on J1939 `boostPressure` (SPN 102).

**Code location:** `lib/config/pid_config.dart:191-198`

---

## Issue 6: `oilTempObd` (PID 0x5C) — NO DATA

**Impact:** MEDIUM

**Log evidence:**
```
20:55:01 warn  ✗ oilTempObd parse_fail cmd=015C raw=NO DATA
```

Not in ECU supported PID bitmap. Cummins provides oil temp via J1939 SPN 175.

**Fix:** Remove from OBD2 polling. Rely on J1939 `oilTemp` (SPN 175).

**Code location:** `lib/config/pid_config.dart:279-286`

---

## Issue 7: `fuelRateObd` (PID 0x5E) — NO DATA

**Impact:** MEDIUM — No fuel rate means no instantMPG calculation

**Log evidence:**
```
20:55:01 warn  ✗ fuelRateObd parse_fail cmd=015E raw=NO DATA
```

Not in ECU supported PID bitmap. Cummins provides fuel rate via J1939 SPN 183.

**Fix:** Remove from OBD2 polling. Rely on J1939 `fuelRate` (SPN 183).

**Code location:** `lib/config/pid_config.dart:287-294`

---

## Issue 8: Mode $22 PIDs all rejected — `transGearCmd`, `transGearActual`, `tcLockStatus`

**Impact:** LOW

**Log evidence:**
```
20:54:53 warn  ✗ transGearCmd disabled — stale value evicted cmd=22A09F reason=negative_resp fails=10
20:54:53 warn  ✗ transGearActual disabled — stale value evicted cmd=22A0A0 reason=negative_resp fails=10
20:54:53 warn  ✗ tcLockStatus disabled — stale value evicted cmd=22B09B reason=negative_resp fails=10
```

All three return `negative_resp` (7F 22 xx — likely NRC 0x31 "requestOutOfRange" or 0x12 "subFunctionNotSupported").

**PID definitions (pid_config.dart:595-618):**
```
transGearCmd:    Mode $22, DID 0xA09F
transGearActual: Mode $22, DID 0xA0A0
tcLockStatus:    Mode $22, DID 0xB09B
```

**Possible causes:**
1. These Mopar DIDs may require extended diagnostic session (`10 03`) first
2. DIDs may be different on 2026 model year Aisin AS69RC
3. May need physical addressing to TCM (not functional broadcast)
4. May need security access (`27` service)

**Fix:** Research correct 2026 DIDs, try extended session, or remove and rely on `estimatedGear` calculation from RPM/speed ratio (already implemented in `drive_recorder.dart:517-539`).

**Code location:** `lib/config/pid_config.dart:594-618`

---

## Issue 9: `batteryVoltage` (PID 0x42) — wrong ECU value, breaks ignition detection

**Impact:** MEDIUM

**Log evidence:**
```
20:53:22 info  ✓ batteryVoltage first success = 10.11 V cmd=0142 raw=18DAF110044142277D\n18DAF1180441422FB3
```

**Raw response breakdown — two ECUs respond:**
```
ECU 0x10:  18DAF110 04 4142 277D   → 0x277D = 10109 → 10109/1000 = 10.11V  ← WRONG (internal logic voltage?)
ECU 0x18:  18DAF118 04 4142 2FB3   → 0x2FB3 = 12211 → 12211/1000 = 12.21V  ← CORRECT (battery voltage)
```

**Datapoint evidence — voltage swings between ECUs:**
```
batteryVoltage: min=10.11, max=14.28, avg=13.59
```
The parser inconsistently picks whichever ECU responds first in the CAN frame. Sometimes ECU 0x10 (10.1V), sometimes ECU 0x18 (12.2-14.3V when alternator is charging).

**Impact on ignition detection:** The engine state machine uses `accessoryVoltageThreshold = 12.8V`. When the parser picks ECU 0x10's 10.1V value, it looks like the engine is off even when the alternator is charging at 14V. This could cause false `off` state transitions → premature BT disconnect.

**Fix options:**
1. For multi-ECU responses, prefer the **higher** voltage value (or filter for ECU 0x18)
2. Use `AT RV` (adapter pin 16 voltage) for ignition detection instead of PID 0x42 — it reads the OBD port voltage directly, no ECU involved
3. The `_readAdapterVoltage()` method already exists (added in ignition detection feature) and writes to `_lastVoltageReading` — make the engine state machine prefer this over PID 0x42

**Code locations:**
- Parser: `lib/services/obd2_parser.dart:144-163` (`_parseSingleLine` picks first match)
- PID def: `lib/config/pid_config.dart:263-270`
- Engine state: `lib/services/obd_service.dart _updateEngineState()`

---

## Issue 10: Command errors after sleep disconnect

**Impact:** LOW — log noise only

**Log evidence:**
```
20:56:04 error OBD Command state error  010C: Bad state: Not connected
20:56:04 error OBD Command state error  AT RV: Bad state: Not connected
20:56:06 error OBD Command state error  010C: Bad state: Not connected
20:56:06 error OBD Command state error  AT RV: Bad state: Not connected
20:56:08 error OBD Command state error  010C: Bad state: Not connected
20:56:08 error OBD Command state error  AT RV: Bad state: Not connected
```

3 pairs of errors at 2-second intervals (= `accessoryPollIntervalMs`). The accessory poll loop sends RPM (`010C`) + AT RV, but BT is already disconnected.

**Root cause:** `_pollAccessoryMode()` doesn't check `_bluetooth.isConnected` between commands. The `disconnectForSleep()` call is async and can fire mid-poll-cycle.

**Fix:** Add `if (!_bluetooth.isConnected) return;` checks in `_pollAccessoryMode()` before each command, or wrap in try/catch for `StateError`.

**Code location:** `lib/services/obd_service.dart _pollAccessoryMode()`

---

## Issue 11: Drive recorded with engine off

**Impact:** LOW — junk data in Firestore

**Log + datapoint evidence:**
```
20:53:16 info  Drive session created driveId=Z4ZgH5rVsNyV7U5pWSuD
20:53:22 info  First datapoint captured — 12 sensors, active: ambientTemp, barometric, batteryVoltage, coolantTemp, exhaustBackpressure, fuelLevel, intakeTemp, rpm, speed
```

The drive started immediately at 20:53:16 (same second as "OBD ready"), before any RPM was read. First RPM reading was 0.00.

```
Drive summary: dur=106s dist=0.0mi mpg=0.0 fuel=0.00gal pts=92 sensors=12
RPM data: min=0, max=769.75, avg=560.25 (engine started during session)
Speed: constant 0 (parked)
```

**Root cause:** `_autoStartRecording` in `live_data_provider.dart:121-135` calls `recorder.startRecording()` immediately when OBD connects, without checking if the engine is running. The speed-based auto-detect (`driveStartSpeedThreshold = 5 mph`) would prevent this, but `_autoStartRecording` bypasses it.

**Fix:** In `_autoStartRecording`, check `obdService.liveData['rpm']` — if null or < 100, defer to auto-detect instead of starting immediately.

**Code location:** `lib/providers/live_data_provider.dart:121-135`

---

## Issue 12: 8 command timeouts during session

**Impact:** LOW — already handled by failure tracking

**Log evidence:**
```
Command timeouts: 8
```

Timeouts waste 2 seconds each (`AppConstants.obdTimeout`). Over a 106-second session with 8 timeouts = 16 seconds lost (15% of session time). These are from unsupported PIDs that the ECU doesn't respond to before `ATST32` (200ms adapter timeout) expires, causing the adapter to return `NO DATA`, which then waits for the full 2-second Dart-side timeout.

**Note:** The `NO DATA` PIDs (throttle, MAP, oil temp, fuel rate) are already disabled after 10 failures. But before disabling, each wastes time.

**Fix:** Use the supported PID bitmap to skip PIDs that the ECU explicitly says it doesn't support. Currently the code says "NOTE: We intentionally do NOT skip PIDs based on the ECU's supported PID bitmap" (obd_service.dart line 618-622) — this was correct when the bitmap had only 14 PIDs, but now with 34 PIDs we can trust it more.

**Code location:** `lib/services/obd_service.dart:608-625 (_getActivePids)`

---

## Priority Order

| # | Issue | Impact | Effort | Description |
|---|-------|--------|--------|-------------|
| 1 | J1939 not connecting | CRITICAL | HIGH | Blocks 20+ diesel sensors — need passive monitoring |
| 9 | Battery voltage wrong ECU | MEDIUM | LOW | Picks 10.1V instead of 12.2V — breaks ignition detection |
| 3 | Rail pressure parse fail | MEDIUM | MEDIUM | PID 0x6D — need raw response capture |
| 2 | Intercooler temp parse | LOW | LOW | responseBytes wrong, need multi-byte parser |
| 11 | Drive recorded engine off | LOW | LOW | Add RPM check in _autoStartRecording |
| 10 | Command errors after disconnect | LOW | LOW | Add isConnected checks in poll loop |
| 4-7 | Unsupported OBD2 PIDs | LOW | LOW | Remove throttle, MAP, oil temp, fuel rate from OBD2 |
| 8 | Mode $22 rejected | LOW | MEDIUM | Research correct 2026 DIDs or remove |
| 12 | Command timeouts | LOW | LOW | Use PID bitmap to skip unsupported |

## Untapped Supported PIDs

The ECU bitmap reports 34 supported PIDs. We only poll 17 of them (some as fast, some fail). These supported PIDs are NOT in our pid_config and could be added:

```
In bitmap but not polled:
0x01 — Monitor status since DTCs cleared (diagnostic info)
0x21 — Distance traveled with MIL on
0x30 — Warm-ups since codes cleared
0x31 — Distance traveled since codes cleared
0x49 — Accelerator pedal position D (THIS could replace throttlePos!)
0x61 — Driver's demand engine torque
0x62 — Actual engine torque
0x63 — Engine reference torque
0x64 — Engine torque data (5 bytes)
0x65 — Auxiliary I/O supported
0x69 — Commanded EGR and EGR error
0x6C — Commanded throttle actuator
0x70 — Boost pressure control
0x71 — VGT control
0x74 — Turbocharger compressor inlet pressure
0x75 — Turbocharger compressor inlet temperature
0x77 — Charge air cooler temperature
0x78 — EGT bank 1 (alternative to J1939 EGT!)
0x7A — DPF temperature
0x7F — Engine run time (extended)
0x80 — PIDs 0x81-0xA0 supported (more ranges available!)
```

Key finds: **0x49** (pedal position), **0x78** (EGT), **0x7A** (DPF temp), **0x70** (boost), **0x71** (VGT) — these could provide some diesel-specific data via OBD2 even without J1939!
