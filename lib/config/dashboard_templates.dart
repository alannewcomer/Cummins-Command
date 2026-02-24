// Prebuilt dashboard templates for common driving scenarios.
// Row-based layout: each row has a fixed height and 1-2 widgets.
//
// Row types:
//   'widgets' — contains DashboardWidget children laid out in a Row
//   'header'  — section title text (no widget container)

class DashboardTemplates {
  DashboardTemplates._();

  /// All templates (3 total).
  static List<Map<String, dynamic>> get all => [
    dailyDriver,
    towingHeatWatch,
    allParams,
  ];

  // ─── Row-based helpers ───

  /// Widget entry for a row-based layout.
  static Map<String, dynamic> _w(String type, String param, {int colSpan = 1}) =>
      {'type': type, 'param': param, 'col': 0, 'row': 0, 'colSpan': colSpan, 'rowSpan': 1};

  /// DataStrip widget entry (multiple params).
  static Map<String, dynamic> _strip(List<String> params, {int colSpan = 2}) =>
      {'type': 'dataStrip', 'param': params.first, 'params': params, 'col': 0, 'row': 0, 'colSpan': colSpan, 'rowSpan': 1};

  /// A widget row definition.
  static Map<String, dynamic> _row(double height, List<Map<String, dynamic>> widgets) =>
      {'type': 'widgets', 'height': height, 'widgets': widgets};

  /// A section header row.
  static Map<String, dynamic> _header(String title) =>
      {'type': 'header', 'height': 32, 'title': title, 'widgets': []};

  // ─── Daily Driver ───

  static Map<String, dynamic> get dailyDriver => {
    'name': 'Daily Driver',
    'description': 'Balanced overview for everyday driving',
    'icon': 'directions_car',
    'source': 'template',
    'layout': {
      'type': 'rows',
      'columns': 2,
      'rows': 9,
      'widgets': [],
      'rowDefs': [
        // Row 0 (160px): boost + RPM
        _row(160, [
          _w('radialGauge', 'boostPressureCtrl'),
          _w('radialGauge', 'rpm'),
        ]),
        // Row 1 (160px): coolant + load
        _row(160, [
          _w('radialGauge', 'coolantTemp'),
          _w('radialGauge', 'engineLoadObd2'),
        ]),
        // Row 2 (120px): speed + EGT
        _row(120, [
          _w('digital', 'speed'),
          _w('digital', 'egtObd2'),
        ]),
        // Row 3 (50px): APP — full width
        _row(50, [
          _w('linearBar', 'accelPedalD', colSpan: 2),
        ]),
        // Row 4 (120px): rail pressure + DPF temp
        _row(120, [
          _w('digital', 'railPressure'),
          _w('digital', 'dpfTemp'),
        ]),
        // Row 5 (50px): EGR + VGT
        _row(50, [
          _w('linearBar', 'commandedEgr'),
          _w('linearBar', 'vgtControlObd'),
        ]),
        // Row 6 (50px): fuel — full width
        _row(50, [
          _w('linearBar', 'fuelLevel', colSpan: 2),
        ]),
        // Row 7 (45px): data strip — battery, ambient, runtime
        _row(45, [
          _strip(['batteryVoltage', 'ambientTemp', 'runTime']),
        ]),
        // Row 8 (100px): sparklines — boost + coolant
        _row(100, [
          _w('sparkline', 'boostPressureCtrl'),
          _w('sparkline', 'coolantTemp'),
        ]),
      ],
    },
  };

  // ─── Towing / Heat Watch ───

  static Map<String, dynamic> get towingHeatWatch => {
    'name': 'Towing / Heat Watch',
    'description': 'Thermal management for towing and heavy loads',
    'icon': 'rv_hookup',
    'source': 'template',
    'layout': {
      'type': 'rows',
      'columns': 2,
      'rows': 9,
      'widgets': [],
      'rowDefs': [
        // Row 0 (160px): EGT + coolant (hero gauges)
        _row(160, [
          _w('radialGauge', 'egtObd2'),
          _w('radialGauge', 'coolantTemp'),
        ]),
        // Row 1 (160px): boost + load
        _row(160, [
          _w('radialGauge', 'boostPressureCtrl'),
          _w('radialGauge', 'engineLoadObd2'),
        ]),
        // Row 2 (50px): APP — full width
        _row(50, [
          _w('linearBar', 'accelPedalD', colSpan: 2),
        ]),
        // Row 3 (120px): RPM + speed
        _row(120, [
          _w('digital', 'rpm'),
          _w('digital', 'speed'),
        ]),
        // Row 4 (120px): DPF temp + rail pressure
        _row(120, [
          _w('digital', 'dpfTemp'),
          _w('digital', 'railPressure'),
        ]),
        // Row 5 (50px): VGT + EGR
        _row(50, [
          _w('linearBar', 'vgtControlObd'),
          _w('linearBar', 'commandedEgr'),
        ]),
        // Row 6 (50px): fuel — full width
        _row(50, [
          _w('linearBar', 'fuelLevel', colSpan: 2),
        ]),
        // Row 7 (45px): data strip — battery, ambient, backpressure
        _row(45, [
          _strip(['batteryVoltage', 'ambientTemp', 'exhaustBackpressure']),
        ]),
        // Row 8 (100px): sparklines — EGT + coolant
        _row(100, [
          _w('sparkline', 'egtObd2'),
          _w('sparkline', 'coolantTemp'),
        ]),
      ],
    },
  };

  // ─── All Parameters (grouped by system) ───

  static Map<String, dynamic> get allParams => {
    'name': 'All Parameters',
    'description': 'Every monitored parameter grouped by system',
    'icon': 'list_alt',
    'source': 'template',
    'layout': {
      'type': 'rows',
      'columns': 2,
      'rows': 18,
      'widgets': [],
      'rowDefs': [
        // ── POWER & DRIVETRAIN ──
        _header('POWER & DRIVETRAIN'),
        _row(160, [
          _w('radialGauge', 'rpm'),
          _w('radialGauge', 'engineLoadObd2'),
        ]),
        _row(120, [
          _w('digital', 'speed'),
          _w('digital', 'actualTorque'),
        ]),
        _row(50, [
          _w('linearBar', 'accelPedalD', colSpan: 2),
        ]),
        _row(120, [
          _w('digital', 'demandTorque'),
          _w('digital', 'commandedThrottle'),
        ]),
        _row(120, [
          _w('digital', 'maf'),
          _w('digital', 'railPressure'),
        ]),

        // ── TURBO & EXHAUST ──
        _header('TURBO & EXHAUST'),
        _row(160, [
          _w('radialGauge', 'boostPressureCtrl'),
          _w('radialGauge', 'egtObd2'),
        ]),
        _row(50, [
          _w('linearBar', 'vgtControlObd'),
          _w('linearBar', 'commandedEgr'),
        ]),
        _row(120, [
          _w('digital', 'turboInletPressure'),
          _w('digital', 'exhaustBackpressure'),
        ]),

        // ── TEMPERATURES ──
        _header('TEMPERATURES'),
        _row(160, [
          _w('radialGauge', 'coolantTemp'),
          _w('radialGauge', 'dpfTemp'),
        ]),
        _row(120, [
          _w('digital', 'intakeTemp'),
          _w('digital', 'chargeAirTemp'),
        ]),
        _row(120, [
          _w('digital', 'intercoolerOutletTemp'),
          _w('digital', 'turboInletTemp'),
        ]),

        // ── VEHICLE & ENVIRONMENT ──
        _header('VEHICLE & ENVIRONMENT'),
        _row(50, [
          _w('linearBar', 'fuelLevel', colSpan: 2),
        ]),
        _row(45, [
          _strip(['batteryVoltage', 'ambientTemp', 'barometric']),
        ]),
        _row(45, [
          _strip(['runTime', 'runtimeExtended', 'referenceTorque']),
        ]),
      ],
    },
  };
}
