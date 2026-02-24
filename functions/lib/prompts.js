'use strict';

// ─── Shared context ──────────────────────────────────────────────────────────

const SYSTEM_CONTEXT = `You are an expert diesel engine analyst specialising in
the 6.7L Cummins turbo-diesel (2019-2026 Ram 2500/3500). You analyse OBD2 and
J1939 sensor data to detect anomalies, predict maintenance needs, and provide
clear recommendations. Always respond in valid JSON.`;

function vehicleDesc(v) {
  const parts = [v.year, v.make, v.model, v.trim].filter(Boolean);
  return parts.length ? parts.join(' ') : 'Unknown vehicle';
}

function formatStats(stats) {
  if (!stats || typeof stats !== 'object') return 'No stats available.';
  const lines = [];
  for (const [key, val] of Object.entries(stats)) {
    if (val != null) lines.push(`  ${key}: ${val}`);
  }
  return lines.join('\n');
}

function driveSummary(d) {
  const parts = [];
  if (d.startTime) parts.push(`start=${d.startTime}`);
  if (d.durationSeconds) parts.push(`duration=${d.durationSeconds}s`);
  if (d.distanceMiles) parts.push(`dist=${d.distanceMiles}mi`);
  if (d.averageMPG) parts.push(`mpg=${d.averageMPG}`);
  if (d.maxBoostPsi) parts.push(`maxBoost=${d.maxBoostPsi}psi`);
  if (d.maxEgtF) parts.push(`maxEGT=${d.maxEgtF}F`);
  if (d.dpfRegenOccurred) parts.push('DPF_REGEN');
  return parts.join(', ');
}

// ─── Prompt builders ─────────────────────────────────────────────────────────

function buildDriveAnalysisPrompt(vehicle, drive, stats) {
  return `${SYSTEM_CONTEXT}

Vehicle: ${vehicleDesc(vehicle)}
Engine: ${vehicle.engine || '6.7L Cummins'}
Odometer: ${vehicle.currentOdometer || 'unknown'} mi

Drive session ${drive.id}:
  Duration: ${drive.durationSeconds || 0}s
  Distance: ${drive.distanceMiles || 0} mi
  Avg MPG: ${drive.averageMPG || 'N/A'}
  Datapoints: ${drive.datapointCount || 0}
  Sensors: ${(drive.sensorList || []).join(', ')}

Parameter Statistics:
${formatStats(stats)}

Also classify this drive with applicable tags from this list:
- "towing" (high sustained load >60%, low speed, high EGT)
- "highway" (avg speed >45 mph, low throttle variance)
- "city" (avg speed <35 mph, high idle %, frequent speed changes)
- "mountain" (sustained high load with altitude/GPS changes)
- "cold_start" (coolant temp <140F at drive start)
- "dpf_regen" (DPF regen detected during drive)
- "hard_driving" (frequent >80% throttle, high RPM variance)
- "efficient" (MPG in top 20% for this vehicle's baseline)

Analyse this drive and respond with JSON:
{
  "summary": "2-3 sentence plain-English summary of the drive",
  "anomalies": ["list of any anomalous readings or patterns"],
  "healthScore": 0-100,
  "recommendations": ["actionable recommendations if any"],
  "autoTags": ["tag1", "tag2"]
}`;
}

function buildRangeAnalysisPrompt(vehicle, drives, params) {
  const driveLines = drives.map((d, i) =>
    `  ${i + 1}. ${driveSummary(d)}`
  ).join('\n');

  return `${SYSTEM_CONTEXT}

Vehicle: ${vehicleDesc(vehicle)}
Engine: ${vehicle.engine || '6.7L Cummins'}

Analyse ${drives.length} drives from ${params.startDate || '?'} to ${params.endDate || '?'}:
${driveLines}

Focus areas: ${params.focus || 'general trends, fuel economy, engine health'}

Respond with JSON:
{
  "summary": "Overall trend summary",
  "trends": ["identified trends"],
  "concerns": ["any concerning patterns"],
  "recommendations": ["actionable recommendations"],
  "healthScore": 0-100
}`;
}

function buildMaintenancePredictionPrompt(vehicle, drives, maintenance) {
  const driveLines = drives.slice(0, 20).map((d, i) =>
    `  ${i + 1}. ${driveSummary(d)}`
  ).join('\n');

  const maintLines = maintenance.slice(0, 20).map((m, i) =>
    `  ${i + 1}. ${m.date || '?'}: ${m.type || m.description || 'maintenance'} (${m.cost ? '$' + m.cost : 'no cost'})`
  ).join('\n');

  return `${SYSTEM_CONTEXT}

Vehicle: ${vehicleDesc(vehicle)}
Engine: ${vehicle.engine || '6.7L Cummins'}
Odometer: ${vehicle.currentOdometer || 'unknown'} mi

Recent drives:
${driveLines || '  None'}

Maintenance history:
${maintLines || '  None'}

Based on driving patterns and maintenance history, predict upcoming maintenance needs.
Respond with JSON:
{
  "predictions": [
    {
      "type": "maintenance type (e.g. oil_change, fuel_filter, def_service)",
      "urgency": "low|medium|high|critical",
      "estimatedDate": "YYYY-MM-DD",
      "estimatedMiles": 0,
      "confidence": 0.0-1.0,
      "reasoning": "why this is predicted"
    }
  ],
  "summary": "overall maintenance outlook"
}`;
}

function buildCustomQueryPrompt(vehicle, drives, params) {
  const driveLines = drives.slice(0, 15).map((d, i) =>
    `  ${i + 1}. ${driveSummary(d)}`
  ).join('\n');

  return `${SYSTEM_CONTEXT}

Vehicle: ${vehicleDesc(vehicle)}
Engine: ${vehicle.engine || '6.7L Cummins'}

Recent drives:
${driveLines}

User question: "${params.query || params.prompt || 'How is my truck doing?'}"

Respond with JSON:
{
  "answer": "detailed answer to the user's question",
  "confidence": 0.0-1.0,
  "relatedMetrics": ["relevant sensor names"],
  "recommendations": ["if applicable"]
}`;
}

function buildDashboardPrompt(vehicle, prompt) {
  return `${SYSTEM_CONTEXT}

Vehicle: ${vehicleDesc(vehicle)}
Engine: ${vehicle.engine || '6.7L Cummins'}

The user wants a custom dashboard: "${prompt}"

Generate a dashboard configuration. Available widget types:
- gauge: circular gauge for a single parameter
- line_chart: time-series line chart
- stat_card: single big number with label
- bar_chart: bar chart comparison

Available parameters: rpm, speed, coolantTemp, boostPressure, egt, egtObd2,
oilTemp, oilPressure, engineLoad, transTemp, turboSpeed, fuelRate, fuelLevel,
batteryVoltage, dpfSootLoad, dpfTemp, defLevel, railPressure, ambientTemp,
instantMPG, estimatedGear, estimatedHP, estimatedTorque, accelPedalD,
demandTorque, actualTorque, commandedEgr, commandedThrottle, boostPressureCtrl,
vgtControlObd, turboInletPressure, turboInletTemp, chargeAirTemp,
intercoolerOutletTemp, exhaustBackpressure.

Respond with JSON:
{
  "name": "dashboard name",
  "description": "what this dashboard monitors",
  "widgets": [
    {
      "type": "gauge|line_chart|stat_card|bar_chart",
      "title": "widget title",
      "parameter": "parameter_name",
      "position": {"row": 0, "col": 0},
      "size": {"rows": 1, "cols": 1},
      "thresholds": {"warning": 0, "critical": 0}
    }
  ]
}`;
}

function buildBaselinePrompt(vehicle, drives) {
  const driveLines = drives.slice(0, 30).map((d, i) =>
    `  ${i + 1}. ${driveSummary(d)}`
  ).join('\n');

  return `${SYSTEM_CONTEXT}

Vehicle: ${vehicleDesc(vehicle)}
Engine: ${vehicle.engine || '6.7L Cummins'}
Odometer: ${vehicle.currentOdometer || 'unknown'} mi

Last 30 days of drives:
${driveLines}

Compute baseline ranges for this vehicle's normal operating parameters.
These baselines will be used to detect anomalies in future drives.

Respond with JSON:
{
  "baselines": {
    "parameterName": {"low": 0, "high": 0, "typical": 0},
    ...
  },
  "notes": "any observations about this vehicle's patterns"
}`;
}

module.exports = {
  buildDriveAnalysisPrompt,
  buildRangeAnalysisPrompt,
  buildMaintenancePredictionPrompt,
  buildCustomQueryPrompt,
  buildDashboardPrompt,
  buildBaselinePrompt,
};
