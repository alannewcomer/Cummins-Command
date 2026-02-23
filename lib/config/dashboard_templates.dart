// Prebuilt dashboard templates for common driving scenarios.
// Each template is a JSON-compatible map that can be stored in Firestore.
//
// Grid layout: widgets fill left-to-right, top-to-bottom.
// col/row are stored for future custom layout support; colSpan/rowSpan = 1.

import 'pid_config.dart';

class DashboardTemplates {
  DashboardTemplates._();

  /// All templates including the dynamic "All Parameters" template.
  /// This is a getter (not const) because allParams is generated at runtime.
  static List<Map<String, dynamic>> get all => [
    dailyDriver,
    towingHeatWatch,
    performance,
    temperatureMonitor,
    allParams,
  ];

  // ─── Helper to build a widget entry ───

  static Map<String, dynamic> _w(String type, String param, int col, int row) =>
      {'type': type, 'param': param, 'col': col, 'row': row, 'colSpan': 1, 'rowSpan': 1};

  // ─── Prebuilt Templates ───

  /// Daily Driver — 3 cols × 5 rows = 15 widgets
  /// Balanced everyday overview: critical gauges, temps, fuel, electrical.
  static Map<String, dynamic> get dailyDriver => {
    'name': 'Daily Driver',
    'description': 'Balanced overview for everyday driving',
    'icon': 'directions_car',
    'source': 'template',
    'layout': {
      'columns': 3,
      'rows': 5,
      'widgets': [
        // Row 0: boost, RPM, coolant
        _w('radialGauge', 'boostPressureCtrl',   0, 0),
        _w('radialGauge', 'rpm',                  1, 0),
        _w('radialGauge', 'coolantTemp',          2, 0),
        // Row 1: EGT, load, pedal
        _w('radialGauge', 'egtObd2',              0, 1),
        _w('radialGauge', 'engineLoadObd2',       1, 1),
        _w('linearBar',   'accelPedalD',          2, 1),
        // Row 2: speed, rail pressure, VGT
        _w('digital',     'speed',                0, 2),
        _w('digital',     'railPressure',         1, 2),
        _w('linearBar',   'vgtControlObd',        2, 2),
        // Row 3: DPF temp, backpressure, EGR
        _w('digital',     'dpfTemp',              0, 3),
        _w('digital',     'exhaustBackpressure',  1, 3),
        _w('linearBar',   'commandedEgr',         2, 3),
        // Row 4: fuel level, battery, ambient
        _w('linearBar',   'fuelLevel',            0, 4),
        _w('digital',     'batteryVoltage',       1, 4),
        _w('digital',     'ambientTemp',          2, 4),
      ],
    },
  };

  /// Towing / Heat Watch — 3 cols × 5 rows = 15 widgets
  /// Thermal management focus: every temp, exhaust monitoring, sparkline trends.
  static Map<String, dynamic> get towingHeatWatch => {
    'name': 'Towing / Heat Watch',
    'description': 'Thermal management for towing and heavy loads',
    'icon': 'rv_hookup',
    'source': 'template',
    'layout': {
      'columns': 3,
      'rows': 5,
      'widgets': [
        // Row 0: EGT, coolant, DPF temp
        _w('radialGauge', 'egtObd2',              0, 0),
        _w('radialGauge', 'coolantTemp',          1, 0),
        _w('radialGauge', 'dpfTemp',              2, 0),
        // Row 1: intercooler, turbo inlet, charge air
        _w('radialGauge', 'intercoolerOutletTemp', 0, 1),
        _w('radialGauge', 'turboInletTemp',       1, 1),
        _w('radialGauge', 'chargeAirTemp',        2, 1),
        // Row 2: backpressure, boost, load
        _w('digital',     'exhaustBackpressure',  0, 2),
        _w('digital',     'boostPressureCtrl',    1, 2),
        _w('linearBar',   'engineLoadObd2',       2, 2),
        // Row 3: VGT, EGR, pedal
        _w('linearBar',   'vgtControlObd',        0, 3),
        _w('linearBar',   'commandedEgr',         1, 3),
        _w('linearBar',   'accelPedalD',          2, 3),
        // Row 4: sparkline trends
        _w('sparkline',   'egtObd2',              0, 4),
        _w('sparkline',   'coolantTemp',          1, 4),
        _w('sparkline',   'dpfTemp',              2, 4),
      ],
    },
  };

  /// Performance — 3 cols × 4 rows = 12 widgets
  /// Power & turbo: boost, torque, VGT, rail pressure, sparkline trends.
  static Map<String, dynamic> get performance => {
    'name': 'Performance',
    'description': 'Power and turbo performance metrics',
    'icon': 'speed',
    'source': 'template',
    'layout': {
      'columns': 3,
      'rows': 4,
      'widgets': [
        // Row 0: boost, RPM, EGT
        _w('radialGauge', 'boostPressureCtrl',    0, 0),
        _w('radialGauge', 'rpm',                  1, 0),
        _w('radialGauge', 'egtObd2',              2, 0),
        // Row 1: torque, VGT, pedal
        _w('radialGauge', 'actualTorque',         0, 1),
        _w('linearBar',   'vgtControlObd',        1, 1),
        _w('linearBar',   'accelPedalD',          2, 1),
        // Row 2: rail pressure, MAF, throttle
        _w('digital',     'railPressure',         0, 2),
        _w('digital',     'maf',                  1, 2),
        _w('digital',     'commandedThrottle',    2, 2),
        // Row 3: sparkline trends
        _w('sparkline',   'boostPressureCtrl',    0, 3),
        _w('sparkline',   'rpm',                  1, 3),
        _w('sparkline',   'actualTorque',         2, 3),
      ],
    },
  };

  /// Temperature Monitor — 3 cols × 4 rows = 12 widgets
  /// Every temperature sensor: warm-up monitoring, cold starts, troubleshooting.
  static Map<String, dynamic> get temperatureMonitor => {
    'name': 'Temperature Monitor',
    'description': 'All temperature sensors for warm-up and diagnostics',
    'icon': 'thermostat',
    'source': 'template',
    'layout': {
      'columns': 3,
      'rows': 4,
      'widgets': [
        // Row 0: coolant, EGT, DPF temp
        _w('radialGauge', 'coolantTemp',          0, 0),
        _w('radialGauge', 'egtObd2',              1, 0),
        _w('radialGauge', 'dpfTemp',              2, 0),
        // Row 1: intake, intercooler, turbo inlet
        _w('digital',     'intakeTemp',           0, 1),
        _w('digital',     'intercoolerOutletTemp', 1, 1),
        _w('digital',     'turboInletTemp',       2, 1),
        // Row 2: charge air, ambient, battery
        _w('digital',     'chargeAirTemp',        0, 2),
        _w('digital',     'ambientTemp',          1, 2),
        _w('digital',     'batteryVoltage',       2, 2),
        // Row 3: sparkline trends
        _w('sparkline',   'coolantTemp',          0, 3),
        _w('sparkline',   'egtObd2',              1, 3),
        _w('sparkline',   'intakeTemp',           2, 3),
      ],
    },
  };

  /// Dynamically generated dashboard showing every PID in the registry.
  /// Uses digital readouts for density; sorted alphabetically.
  static Map<String, dynamic> get allParams {
    final pids = PidRegistry.allSorted;
    final widgets = <Map<String, dynamic>>[];
    for (int i = 0; i < pids.length; i++) {
      widgets.add({
        'type': 'digital',
        'param': pids[i].id,
        'col': i % 3,
        'row': i ~/ 3,
        'colSpan': 1,
        'rowSpan': 1,
      });
    }
    return {
      'name': 'All Parameters',
      'description': 'Every monitored parameter — scroll to see all',
      'icon': 'list_alt',
      'source': 'template',
      'layout': {
        'columns': 3,
        'childAspectRatio': 1.3,
        'rows': (pids.length / 3).ceil(),
        'widgets': widgets,
      },
    };
  }

  static Map<String, dynamic>? getByName(String name) {
    try {
      return all.firstWhere((t) => t['name'] == name);
    } catch (_) {
      return null;
    }
  }
}
