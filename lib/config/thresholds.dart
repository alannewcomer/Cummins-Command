// Default alert thresholds for 6.7L Cummins diesel.
// Every parameter is user-configurable; these are stock defaults.

class ThresholdLevel {
  final double? warnLow;
  final double? warnHigh;
  final double? critLow;
  final double? critHigh;

  const ThresholdLevel({
    this.warnLow,
    this.warnHigh,
    this.critLow,
    this.critHigh,
  });

  ThresholdState evaluate(double value) {
    if (critLow != null && value <= critLow!) return ThresholdState.critical;
    if (critHigh != null && value >= critHigh!) return ThresholdState.critical;
    if (warnLow != null && value <= warnLow!) return ThresholdState.warning;
    if (warnHigh != null && value >= warnHigh!) return ThresholdState.warning;
    return ThresholdState.normal;
  }
}

enum ThresholdState { normal, warning, critical }

class DefaultThresholds {
  DefaultThresholds._();

  static const Map<String, ThresholdLevel> values = {
    'egtObd2': ThresholdLevel(warnHigh: 1100, critHigh: 1400),
    'coolantTemp': ThresholdLevel(warnHigh: 220, critHigh: 240),
    'railPressure': ThresholdLevel(
      warnLow: 4000, critLow: 3000,
      warnHigh: 28000, critHigh: 29000,
    ),
    'batteryVoltage': ThresholdLevel(warnLow: 11.5, critLow: 10.5),
    'fuelLevel': ThresholdLevel(warnLow: 15, critLow: 5),
    'intakeTemp': ThresholdLevel(warnHigh: 160, critHigh: 200),
    'intercoolerOutletTemp': ThresholdLevel(warnHigh: 180, critHigh: 220),
    'exhaustBackpressure': ThresholdLevel(warnHigh: 20, critHigh: 30),
  };

  static ThresholdLevel? forPid(String pidId) => values[pidId];

  static ThresholdState evaluate(String pidId, double value) {
    final threshold = values[pidId];
    if (threshold == null) return ThresholdState.normal;
    return threshold.evaluate(value);
  }
}
