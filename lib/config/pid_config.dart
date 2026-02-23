// PID and SPN definitions for OBD2 and J1939 Cummins parameters.
// Config-driven: add new PIDs here and the app automatically supports them.

enum PollTier { fast, medium, slow, background }

enum PidProtocol { obd2, mode22 }

class PidDefinition {
  final String id;
  final String name;
  final String shortName;
  final String unit;
  final PidProtocol protocol;
  final int code; // PID hex for OBD2/Mode22, SPN for J1939
  final int? mode; // OBD2 mode (usually 0x01)
  final int responseBytes;
  final PollTier tier;
  final double minValue;
  final double maxValue;
  final double? normalMin;
  final double? normalMax;
  final bool isCritical;
  final String aiContext;
  final double Function(List<int> bytes) parser;

  const PidDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.unit,
    required this.protocol,
    required this.code,
    this.mode,
    required this.responseBytes,
    required this.tier,
    required this.minValue,
    required this.maxValue,
    this.normalMin,
    this.normalMax,
    required this.isCritical,
    required this.aiContext,
    required this.parser,
  });
}

// ─── Standard OBD2 Parsers ───

double _parseTemp(List<int> b) => (b[0] - 40) * 9 / 5 + 32; // °C to °F
double _parseRpm(List<int> b) => ((b[0] * 256) + b[1]) / 4.0;
double _parseSingleByte(List<int> b) => b[0].toDouble();
double _parseMaf(List<int> b) => ((b[0] * 256) + b[1]) / 100.0;
double _parseVoltage(List<int> b) => ((b[0] * 256) + b[1]) / 1000.0;
double _parseRuntime(List<int> b) => ((b[0] * 256) + b[1]).toDouble();
double _parsePercent(List<int> b) => b[0] * 100 / 255.0;
double _parseBarometric(List<int> b) => b[0].toDouble();

// OBD2 PID 0x6D — Fuel pressure control system (rail pressure, 6 data bytes)
// Big-endian (OBD2 standard), bytes D-E = actual pressure
double _parseRailPressureActual(List<int> b) =>
    b.length >= 5 ? (b[3] * 256 + b[4]) * 1.45 : 0; // kPa to PSI

// OBD2 PID 0x73 — Exhaust backpressure (2 bytes big-endian, 0.01 kPa/bit)
double _parseExhaustBackpressure(List<int> b) =>
    b.length >= 2 ? (b[0] * 256 + b[1]) * 0.01 : 0;

// ─── New OBD2 Parsers for Diesel-Specific PIDs ───

// PID 0x61/0x62 — Demand/Actual Torque % (1 byte, -125 to +125%)
double _parseTorquePercent(List<int> b) => b[0] - 125.0;

// PID 0x63 — Reference Torque (2 bytes, Nm)
double _parseReferenceTorque(List<int> b) => (b[0] * 256 + b[1]).toDouble();

// PID 0x69 — Commanded EGR % (2 bytes: A=EGR%, B=EGR error, only A used)

// PID 0x78 — EGT Bank 1 (2 bytes, 0.1°C/bit - 40 → °F)
double _parseEgtObd2(List<int> b) =>
    ((b[0] * 256 + b[1]) / 10.0 - 40) * 9 / 5 + 32;

// PID 0x7A — DPF Temperature (same formula as EGT OBD2)
double _parseDpfTemp(List<int> b) =>
    ((b[0] * 256 + b[1]) / 10.0 - 40) * 9 / 5 + 32;

// PID 0x6B — Intercooler outlet temp (SAE J1979: [A=bitmap] [B,C=temp])
// Skip bitmap byte A, use B-C for temperature (0.1°C/bit - 40 → °F)
double _parseIntercoolerOutletTemp(List<int> b) =>
    b.length >= 3 ? ((b[1] * 256 + b[2]) / 10.0 - 40) * 9 / 5 + 32 : 0;

// PID 0x70 — Boost Pressure Control (4 bytes: AB=commanded, CD=actual, kPa→PSI)
double _parseBoostPressureCtrl(List<int> b) =>
    b.length >= 2 ? (b[0] * 256 + b[1]) * 0.03125 * 0.145038 : 0;

// PID 0x71 — VGT Control (4 bytes: AB=commanded %, CD=actual %)
double _parseVgtCtrlObd(List<int> b) =>
    b.length >= 2 ? (b[0] * 256 + b[1]) * 100 / 65535.0 : 0;

// PID 0x74 — Turbo Inlet Pressure (2 bytes, kPa→PSI, same as boost ctrl)
double _parseTurboInletPressure(List<int> b) =>
    b.length >= 2 ? (b[0] * 256 + b[1]) * 0.03125 * 0.145038 : 0;

// PID 0x75 — Turbo Inlet Temperature (2 bytes, 0.1°C/bit - 40 → °F)
double _parseTurboInletTemp(List<int> b) =>
    b.length >= 2 ? ((b[0] * 256 + b[1]) / 10.0 - 40) * 9 / 5 + 32 : 0;

// PID 0x7F — Runtime extended (first 2 bytes = primary runtime field, seconds)
// Full response is 15 bytes multi-frame with multiple sub-values (idle, PTO, etc.)
// Only the first 2 bytes are a valid single runtime counter.
double _parseRuntimeExtended(List<int> b) =>
    b.length >= 2 ? (b[0] * 256 + b[1]).toDouble() : 0;

// Mode $22 parsers removed — transGearCmd, transGearActual, tcLockStatus all
// return 7F negative on 2026 Cummins. J1939 gearRatio + estimatedGear used instead.

/// Master PID registry — add new PIDs here and they're available everywhere.
class PidRegistry {
  PidRegistry._();

  static final Map<String, PidDefinition> _pids = {
    // ─── Standard OBD2 PIDs (Mode 01) ───
    'engineLoadObd2': PidDefinition(
      id: 'engineLoadObd2', name: 'Engine Load (OBD2)', shortName: 'LOAD',
      unit: '%', protocol: PidProtocol.obd2, code: 0x04, mode: 0x01,
      responseBytes: 1, tier: PollTier.fast,
      minValue: 0, maxValue: 100, normalMin: 0, normalMax: 100,
      isCritical: true, aiContext: 'Calculated engine load via OBD2. 100% = full rated power.',
      parser: _parsePercent,
    ),
    'coolantTemp': PidDefinition(
      id: 'coolantTemp', name: 'Coolant Temperature', shortName: 'CLT',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x05, mode: 0x01,
      responseBytes: 1, tier: PollTier.fast,
      minValue: -40, maxValue: 300, normalMin: 180, normalMax: 210,
      isCritical: true, aiContext: 'Engine coolant temperature. Normal operating range 180-210°F for 6.7L Cummins.',
      parser: _parseTemp,
    ),
    // intakeManifoldPressure (0x0B) — REMOVED: returns NO DATA on 2026 Cummins.
    // J1939 boost pressure (SPN 102) is the diesel equivalent.
    'rpm': PidDefinition(
      id: 'rpm', name: 'Engine RPM', shortName: 'RPM',
      unit: 'rpm', protocol: PidProtocol.obd2, code: 0x0C, mode: 0x01,
      responseBytes: 2, tier: PollTier.fast,
      minValue: 0, maxValue: 6000, normalMin: 600, normalMax: 3200,
      isCritical: true, aiContext: 'Engine speed. 6.7L Cummins red line ~3200 RPM, normal idle 650-750 RPM.',
      parser: _parseRpm,
    ),
    'speed': PidDefinition(
      id: 'speed', name: 'Vehicle Speed', shortName: 'SPD',
      unit: 'mph', protocol: PidProtocol.obd2, code: 0x0D, mode: 0x01,
      responseBytes: 1, tier: PollTier.fast,
      minValue: 0, maxValue: 160, normalMin: 0, normalMax: 80,
      isCritical: false, aiContext: 'Vehicle speed in mph.',
      parser: _parseSingleByte,
    ),
    'intakeTemp': PidDefinition(
      id: 'intakeTemp', name: 'Intake Air Temperature', shortName: 'IAT',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x0F, mode: 0x01,
      responseBytes: 1, tier: PollTier.slow,
      minValue: -40, maxValue: 300, normalMin: 40, normalMax: 160,
      isCritical: false, aiContext: 'Intake air temperature after intercooler.',
      parser: _parseTemp,
    ),
    'maf': PidDefinition(
      id: 'maf', name: 'MAF Air Flow Rate', shortName: 'MAF',
      unit: 'g/s', protocol: PidProtocol.obd2, code: 0x10, mode: 0x01,
      responseBytes: 2, tier: PollTier.medium,
      minValue: 0, maxValue: 655, normalMin: 5, normalMax: 400,
      isCritical: false, aiContext: 'Mass air flow sensor reading.',
      parser: _parseMaf,
    ),
    // throttlePos (0x11) — REMOVED: returns NO DATA on 2026 Cummins.
    // Replaced by accelPedalD (0x49) which is supported.
    'runTime': PidDefinition(
      id: 'runTime', name: 'Run Time Since Start', shortName: 'RUN',
      unit: 'sec', protocol: PidProtocol.obd2, code: 0x1F, mode: 0x01,
      responseBytes: 2, tier: PollTier.background,
      minValue: 0, maxValue: 65535, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Seconds since engine start.',
      parser: _parseRuntime,
    ),
    'fuelLevel': PidDefinition(
      id: 'fuelLevel', name: 'Fuel Tank Level', shortName: 'FUEL',
      unit: '%', protocol: PidProtocol.obd2, code: 0x2F, mode: 0x01,
      responseBytes: 1, tier: PollTier.background,
      minValue: 0, maxValue: 100, normalMin: 15, normalMax: 100,
      isCritical: false, aiContext: 'Fuel tank level percentage.',
      parser: _parsePercent,
    ),
    'barometric': PidDefinition(
      id: 'barometric', name: 'Barometric Pressure', shortName: 'BARO',
      unit: 'kPa', protocol: PidProtocol.obd2, code: 0x33, mode: 0x01,
      responseBytes: 1, tier: PollTier.background,
      minValue: 0, maxValue: 255, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Atmospheric barometric pressure.',
      parser: _parseBarometric,
    ),
    'batteryVoltage': PidDefinition(
      id: 'batteryVoltage', name: 'Control Module Voltage', shortName: 'BATT',
      unit: 'V', protocol: PidProtocol.obd2, code: 0x42, mode: 0x01,
      responseBytes: 2, tier: PollTier.background,
      minValue: 0, maxValue: 65, normalMin: 12.0, normalMax: 14.5,
      isCritical: false, aiContext: 'Battery / charging system voltage.',
      parser: _parseVoltage,
    ),
    'ambientTemp': PidDefinition(
      id: 'ambientTemp', name: 'Ambient Air Temperature', shortName: 'AMB',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x46, mode: 0x01,
      responseBytes: 1, tier: PollTier.background,
      minValue: -40, maxValue: 215, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Outside ambient air temperature.',
      parser: _parseTemp,
    ),
    // oilTempObd (0x5C) — REMOVED: returns NO DATA on 2026 Cummins.
    // J1939 oilTemp (SPN 175) provides this data.
    // fuelRateObd (0x5E) — REMOVED: returns NO DATA on 2026 Cummins.
    // J1939 fuelRate (SPN 183) provides this data.
    // OBD2 PID 0x6B — Intercooler outlet / charge air cooler temperature
    // SAE J1979 format: [A=bitmap] [B,C=temp in 0.1°C/bit - 40]
    'intercoolerOutletTemp': PidDefinition(
      id: 'intercoolerOutletTemp', name: 'Intercooler Outlet Temperature', shortName: 'IACT',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x6B, mode: 0x01,
      responseBytes: 3, tier: PollTier.slow,
      minValue: -40, maxValue: 300, normalMin: 40, normalMax: 200,
      isCritical: false, aiContext: 'Aftercooler / charge air cooler outlet temperature.',
      parser: _parseIntercoolerOutletTemp,
    ),
    // OBD2 PID 0x6D — Fuel pressure control system (rail pressure actual)
    // 6 data bytes: A (status) + BC (commanded kPa) + DE (actual kPa) + F (fuel temp)
    // Only one entry to avoid duplicate 016D commands wasting bus time.
    'railPressure': PidDefinition(
      id: 'railPressure', name: 'Rail Pressure', shortName: 'RAIL',
      unit: 'PSI', protocol: PidProtocol.obd2, code: 0x6D, mode: 0x01,
      responseBytes: 6, tier: PollTier.medium,
      minValue: 0, maxValue: 35000, normalMin: 5000, normalMax: 29000,
      isCritical: true, aiContext: 'Actual common rail fuel pressure. Low = check fuel filter or CP3 pump.',
      parser: _parseRailPressureActual,
    ),
    // OBD2 PID 0x73 — Exhaust backpressure
    'exhaustBackpressure': PidDefinition(
      id: 'exhaustBackpressure', name: 'Exhaust Backpressure', shortName: 'EBP',
      unit: 'kPa', protocol: PidProtocol.obd2, code: 0x73, mode: 0x01,
      responseBytes: 2, tier: PollTier.slow,
      minValue: 0, maxValue: 500, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Exhaust backpressure. Elevated values indicate restricted exhaust or DPF.',
      parser: _parseExhaustBackpressure,
    ),

    // ─── New OBD2 Diesel-Specific PIDs (confirmed in ECU bitmap) ───
    'accelPedalD': PidDefinition(
      id: 'accelPedalD', name: 'Accelerator Pedal Position', shortName: 'APP',
      unit: '%', protocol: PidProtocol.obd2, code: 0x49, mode: 0x01,
      responseBytes: 1, tier: PollTier.fast,
      minValue: 0, maxValue: 100, normalMin: 0, normalMax: 100,
      isCritical: false, aiContext: 'Accelerator pedal position. Replaces throttle PID 0x11 on diesel.',
      parser: _parsePercent,
    ),
    'demandTorque': PidDefinition(
      id: 'demandTorque', name: 'Demand Torque %', shortName: 'DT%',
      unit: '%', protocol: PidProtocol.obd2, code: 0x61, mode: 0x01,
      responseBytes: 1, tier: PollTier.medium,
      minValue: -125, maxValue: 125, normalMin: -10, normalMax: 100,
      isCritical: false, aiContext: 'Engine demand torque percentage. -125 to +125%.',
      parser: _parseTorquePercent,
    ),
    'actualTorque': PidDefinition(
      id: 'actualTorque', name: 'Actual Torque %', shortName: 'AT%',
      unit: '%', protocol: PidProtocol.obd2, code: 0x62, mode: 0x01,
      responseBytes: 1, tier: PollTier.medium,
      minValue: -125, maxValue: 125, normalMin: -10, normalMax: 100,
      isCritical: false, aiContext: 'Engine actual torque percentage. Used for HP/torque calculation.',
      parser: _parseTorquePercent,
    ),
    'referenceTorque': PidDefinition(
      id: 'referenceTorque', name: 'Reference Torque', shortName: 'REF-T',
      unit: 'Nm', protocol: PidProtocol.obd2, code: 0x63, mode: 0x01,
      responseBytes: 2, tier: PollTier.background,
      minValue: 0, maxValue: 65535, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Engine reference torque in Nm. Base for HP calculation.',
      parser: _parseReferenceTorque,
    ),
    'commandedEgr': PidDefinition(
      id: 'commandedEgr', name: 'Commanded EGR %', shortName: 'EGR-C',
      unit: '%', protocol: PidProtocol.obd2, code: 0x69, mode: 0x01,
      responseBytes: 2, tier: PollTier.medium,
      minValue: 0, maxValue: 100, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Commanded EGR valve opening percentage.',
      parser: _parsePercent,
    ),
    'commandedThrottle': PidDefinition(
      id: 'commandedThrottle', name: 'Commanded Throttle', shortName: 'THR-C',
      unit: '%', protocol: PidProtocol.obd2, code: 0x6C, mode: 0x01,
      responseBytes: 1, tier: PollTier.medium,
      minValue: 0, maxValue: 100, normalMin: 0, normalMax: 100,
      isCritical: false, aiContext: 'Commanded throttle actuator position.',
      parser: _parsePercent,
    ),
    'boostPressureCtrl': PidDefinition(
      id: 'boostPressureCtrl', name: 'Boost Pressure Control', shortName: 'BST-C',
      unit: 'PSI', protocol: PidProtocol.obd2, code: 0x70, mode: 0x01,
      responseBytes: 4, tier: PollTier.medium,
      minValue: 0, maxValue: 60, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Boost pressure control — commanded boost target in PSI.',
      parser: _parseBoostPressureCtrl,
    ),
    'vgtControlObd': PidDefinition(
      id: 'vgtControlObd', name: 'VGT Control (OBD2)', shortName: 'VGT-O',
      unit: '%', protocol: PidProtocol.obd2, code: 0x71, mode: 0x01,
      responseBytes: 4, tier: PollTier.medium,
      minValue: 0, maxValue: 100, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'VGT position from OBD2. Cross-ref with J1939 vgtPosition.',
      parser: _parseVgtCtrlObd,
    ),
    'turboInletPressure': PidDefinition(
      id: 'turboInletPressure', name: 'Turbo Inlet Pressure', shortName: 'TIP',
      unit: 'PSI', protocol: PidProtocol.obd2, code: 0x74, mode: 0x01,
      responseBytes: 2, tier: PollTier.slow,
      minValue: 0, maxValue: 30, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Turbocharger compressor inlet pressure. Low = restricted air filter.',
      parser: _parseTurboInletPressure,
    ),
    'turboInletTemp': PidDefinition(
      id: 'turboInletTemp', name: 'Turbo Inlet Temperature', shortName: 'TIT',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x75, mode: 0x01,
      responseBytes: 2, tier: PollTier.slow,
      minValue: -40, maxValue: 400, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Turbo compressor inlet air temperature. Compare with ambient for intercooler check.',
      parser: _parseTurboInletTemp,
    ),
    'chargeAirTemp': PidDefinition(
      id: 'chargeAirTemp', name: 'Charge Air Temperature', shortName: 'CAT',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x77, mode: 0x01,
      responseBytes: 2, tier: PollTier.slow,
      minValue: -40, maxValue: 400, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Charge air cooler outlet temperature. Indicates intercooler health.',
      parser: _parseTurboInletTemp, // Same formula: 0.1°C/bit - 40 → °F
    ),
    'egtObd2': PidDefinition(
      id: 'egtObd2', name: 'EGT (OBD2)', shortName: 'EGT-O',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x78, mode: 0x01,
      responseBytes: 2, tier: PollTier.fast,
      minValue: 0, maxValue: 1800, normalMin: 400, normalMax: 900,
      isCritical: true, aiContext: 'Exhaust gas temperature via OBD2. OBD2 alternative to J1939 EGT.',
      parser: _parseEgtObd2,
    ),
    'dpfTemp': PidDefinition(
      id: 'dpfTemp', name: 'DPF Temperature', shortName: 'DPF-T',
      unit: '°F', protocol: PidProtocol.obd2, code: 0x7A, mode: 0x01,
      responseBytes: 2, tier: PollTier.slow,
      minValue: 0, maxValue: 1800, normalMin: null, normalMax: null,
      isCritical: true, aiContext: 'DPF inlet temperature. Spikes during active regen.',
      parser: _parseDpfTemp,
    ),
    'runtimeExtended': PidDefinition(
      id: 'runtimeExtended', name: 'Runtime Extended', shortName: 'RUN-X',
      unit: 'sec', protocol: PidProtocol.obd2, code: 0x7F, mode: 0x01,
      responseBytes: 2, tier: PollTier.background,
      minValue: 0, maxValue: 65535, normalMin: null, normalMax: null,
      isCritical: false, aiContext: 'Extended engine runtime counter in seconds.',
      parser: _parseRuntimeExtended,
    ),

    // ─── Mode $22 Mopar Enhanced PIDs ───
    // transGearCmd (0xA09F) — REMOVED: returns 7F negative on 2026 Cummins.
    // transGearActual (0xA0A0) — REMOVED: returns 7F negative on 2026 Cummins.
    // tcLockStatus (0xB09B) — REMOVED: returns 7F negative on 2026 Cummins.
    // J1939 gearRatio (SPN 513) and estimatedGear calculation already work.
  };

  static Map<String, PidDefinition> get all => Map.unmodifiable(_pids);

  static PidDefinition? get(String id) => _pids[id];

  static List<PidDefinition> getByTier(PollTier tier) =>
      _pids.values.where((p) => p.tier == tier).toList();

  static List<PidDefinition> get critical =>
      _pids.values.where((p) => p.isCritical).toList();

  static List<PidDefinition> getByProtocol(PidProtocol protocol) =>
      _pids.values.where((p) => p.protocol == protocol).toList();

  static List<PidDefinition> get allSorted {
    final list = _pids.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
