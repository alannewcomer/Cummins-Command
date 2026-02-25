import 'package:flutter/material.dart';

/// Static maintenance definitions from the 2026 Ram 2500 owner's manual.
/// These are compile-time constants — user customizations stored per vehicle.

// ─── Service Type Templates (Mileage/Time Scheduled) ───

class ServiceTypeTemplate {
  final String id;
  final String name;
  final IconData icon;
  final int defaultIntervalMiles;
  final int? defaultIntervalMonths;
  final int? defaultIntervalHours; // engine hours — whichever comes first
  final String? notes;
  final String category;

  const ServiceTypeTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.defaultIntervalMiles,
    this.defaultIntervalMonths,
    this.defaultIntervalHours,
    this.notes,
    required this.category,
  });
}

const kServiceTypes = <ServiceTypeTemplate>[
  // Engine
  ServiceTypeTemplate(
    id: 'oil_change',
    name: 'Engine Oil & Filter',
    icon: Icons.oil_barrel,
    defaultIntervalMiles: 15000,
    defaultIntervalMonths: 12,
    defaultIntervalHours: 500,
    notes: 'CK-4 or FA-4 rated 5W-40 synthetic. 12 qt capacity. '
        'Whichever comes first: miles, months, hours, or oil life indicator.',
    category: 'Engine',
  ),
  ServiceTypeTemplate(
    id: 'fuel_filter',
    name: 'Fuel Filter Replacement',
    icon: Icons.filter_alt,
    defaultIntervalMiles: 15000,
    defaultIntervalMonths: 12,
    defaultIntervalHours: 500,
    notes: 'Replace fuel/water separator filter. Drain water weekly. '
        'Whichever comes first: miles, months, or hours.',
    category: 'Engine',
  ),
  ServiceTypeTemplate(
    id: 'air_filter',
    name: 'Engine Air Filter',
    icon: Icons.air,
    defaultIntervalMiles: 30000,
    defaultIntervalMonths: 24,
    notes: 'Inspect every 15k, replace every 30k or when indicator triggers.',
    category: 'Engine',
  ),
  ServiceTypeTemplate(
    id: 'crankcase_vent',
    name: 'Crankcase Vent Filter',
    icon: Icons.filter_list,
    defaultIntervalMiles: 67500,
    notes: 'Also called CCV filter. Replace with engine air filter.',
    category: 'Engine',
  ),
  ServiceTypeTemplate(
    id: 'valve_adjustment',
    name: 'Valve Lash Adjustment',
    icon: Icons.tune,
    defaultIntervalMiles: 150000,
    notes: 'Inspect/adjust valve clearance. Critical for longevity.',
    category: 'Engine',
  ),
  // Exhaust / Emissions
  ServiceTypeTemplate(
    id: 'def_fluid',
    name: 'DEF Fluid Top-Off',
    icon: Icons.water_drop,
    defaultIntervalMiles: 10000,
    notes: 'API certified DEF only. ~2.5 gal/tank fill. Never dilute.',
    category: 'Emissions',
  ),
  ServiceTypeTemplate(
    id: 'dpf_cleaning',
    name: 'DPF Inspection/Cleaning',
    icon: Icons.cleaning_services,
    defaultIntervalMiles: 100000,
    notes: 'Ash cleaning. Monitor regen frequency and back-pressure.',
    category: 'Emissions',
  ),
  // Drivetrain
  ServiceTypeTemplate(
    id: 'transmission_fluid',
    name: 'Transmission Fluid & Filter',
    icon: Icons.settings,
    defaultIntervalMiles: 60000,
    defaultIntervalMonths: 48,
    notes: '68RFE: ATF+4 only. Drop pan, replace filter and gasket.',
    category: 'Drivetrain',
  ),
  ServiceTypeTemplate(
    id: 'transfer_case',
    name: 'Transfer Case Fluid',
    icon: Icons.swap_vert,
    defaultIntervalMiles: 60000,
    defaultIntervalMonths: 48,
    notes: 'ATF+4 for BW44-47 transfer case.',
    category: 'Drivetrain',
  ),
  ServiceTypeTemplate(
    id: 'front_diff',
    name: 'Front Axle Fluid',
    icon: Icons.compare_arrows,
    defaultIntervalMiles: 60000,
    defaultIntervalMonths: 48,
    notes: '75W-90 gear oil. Check for leaks at seals.',
    category: 'Drivetrain',
  ),
  ServiceTypeTemplate(
    id: 'rear_diff',
    name: 'Rear Axle Fluid',
    icon: Icons.compare_arrows,
    defaultIntervalMiles: 60000,
    defaultIntervalMonths: 48,
    notes: '75W-140 synthetic. Add friction modifier if limited-slip.',
    category: 'Drivetrain',
  ),
  // Cooling
  ServiceTypeTemplate(
    id: 'coolant_flush',
    name: 'Coolant Flush',
    icon: Icons.thermostat,
    defaultIntervalMiles: 150000,
    defaultIntervalMonths: 60,
    notes: 'OAT coolant only (MOPAR 10 Year). 6.7L holds ~24 qt.',
    category: 'Cooling',
  ),
  // Brakes / Chassis
  ServiceTypeTemplate(
    id: 'brake_service',
    name: 'Brake Inspection',
    icon: Icons.disc_full,
    defaultIntervalMiles: 30000,
    defaultIntervalMonths: 24,
    notes: 'Inspect pads, rotors, lines, fluid level. HD pads recommended.',
    category: 'Chassis',
  ),
  ServiceTypeTemplate(
    id: 'tire_rotation',
    name: 'Tire Rotation',
    icon: Icons.tire_repair,
    defaultIntervalMiles: 7500,
    defaultIntervalMonths: 6,
    notes: 'Front-to-rear same side for LT tires. Check pressure.',
    category: 'Chassis',
  ),
  ServiceTypeTemplate(
    id: 'serpentine_belt',
    name: 'Serpentine Belt',
    icon: Icons.sync,
    defaultIntervalMiles: 100000,
    notes: 'Inspect for cracks every 30k. Replace by 100k.',
    category: 'Engine',
  ),
];

/// Lookup service type by id.
ServiceTypeTemplate? getServiceType(String id) {
  for (final t in kServiceTypes) {
    if (t.id == id) return t;
  }
  return null;
}

// ─── Checklist Templates ───

class ChecklistItemTemplate {
  final String id;
  final String label;
  final String? tip;

  const ChecklistItemTemplate({
    required this.id,
    required this.label,
    this.tip,
  });
}

class ChecklistTemplate {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<ChecklistItemTemplate> items;

  const ChecklistTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.items,
  });
}

const kChecklists = <ChecklistTemplate>[
  ChecklistTemplate(
    id: 'pre_trip',
    name: 'Pre-Trip / Monthly',
    description: 'Quick walk-around and under-hood checks',
    icon: Icons.checklist,
    items: [
      ChecklistItemTemplate(id: 'engine_oil', label: 'Engine oil level', tip: 'Check with engine warm, on level surface'),
      ChecklistItemTemplate(id: 'coolant', label: 'Coolant level', tip: 'Check overflow tank — never open hot radiator cap'),
      ChecklistItemTemplate(id: 'def_level', label: 'DEF fluid level', tip: 'Gauge on dash or visual check'),
      ChecklistItemTemplate(id: 'tire_pressure', label: 'Tire pressure & condition', tip: 'Cold pressure: 65 PSI front, 65 PSI rear (unloaded)'),
      ChecklistItemTemplate(id: 'lights', label: 'All lights & signals', tip: 'Headlights, taillights, turn signals, brake lights'),
      ChecklistItemTemplate(id: 'belts_hoses', label: 'Belts & hoses visual', tip: 'Look for cracks, leaks, fraying'),
      ChecklistItemTemplate(id: 'battery', label: 'Battery terminals & cables', tip: 'Clean corrosion, check tightness'),
      ChecklistItemTemplate(id: 'under_vehicle', label: 'Under-vehicle leak check', tip: 'Look for fresh fluid spots on ground'),
    ],
  ),
  ChecklistTemplate(
    id: 'storage_prep',
    name: 'Long-Term Storage Prep',
    description: 'Preparing for 30+ days of non-use',
    icon: Icons.warehouse,
    items: [
      ChecklistItemTemplate(id: 'fuel_stabilizer', label: 'Add fuel stabilizer & fill tank', tip: 'Prevents fuel degradation and condensation'),
      ChecklistItemTemplate(id: 'oil_change', label: 'Fresh oil & filter change', tip: 'Used oil contains acids — change before storage'),
      ChecklistItemTemplate(id: 'battery_tender', label: 'Connect battery tender', tip: 'Maintain charge without overcharging'),
      ChecklistItemTemplate(id: 'tire_pressure_up', label: 'Inflate tires to max sidewall', tip: 'Prevents flat spots during storage'),
      ChecklistItemTemplate(id: 'exhaust_cover', label: 'Cover exhaust & intake openings', tip: 'Prevents moisture and rodent entry'),
    ],
  ),
];

/// Lookup checklist template by id.
ChecklistTemplate? getChecklist(String id) {
  for (final c in kChecklists) {
    if (c.id == id) return c;
  }
  return null;
}

// ─── Seasonal Group Templates ───

class SeasonalTaskTemplate {
  final String id;
  final String label;
  final String? tip;

  const SeasonalTaskTemplate({
    required this.id,
    required this.label,
    this.tip,
  });
}

class SeasonalGroupTemplate {
  final String id;
  final String name;
  final String season;
  final List<int> activeMonths;
  final IconData icon;
  final List<SeasonalTaskTemplate> tasks;

  const SeasonalGroupTemplate({
    required this.id,
    required this.name,
    required this.season,
    required this.activeMonths,
    required this.icon,
    required this.tasks,
  });

  bool get isActive => activeMonths.contains(DateTime.now().month);
}

const kSeasonalGroups = <SeasonalGroupTemplate>[
  SeasonalGroupTemplate(
    id: 'winter_prep',
    name: 'Winter Prep',
    season: 'Winter',
    activeMonths: [10, 11, 12, 1, 2, 3],
    icon: Icons.ac_unit,
    tasks: [
      SeasonalTaskTemplate(id: 'block_heater', label: 'Test block heater', tip: 'Verify plug, cord, and element. Use below 0°F.'),
      SeasonalTaskTemplate(id: 'battery_test', label: 'Load-test both batteries', tip: 'Diesel needs strong CCA for cold starts'),
      SeasonalTaskTemplate(id: 'coolant_test', label: 'Test coolant freeze point', tip: 'Should protect to -34°F or lower'),
      SeasonalTaskTemplate(id: 'fuel_treatment', label: 'Add anti-gel fuel treatment', tip: 'Diesel #2 gels at ~15°F. Use every fill-up.'),
      SeasonalTaskTemplate(id: 'wipers_washer', label: 'Winter wipers & washer fluid', tip: 'De-icer rated washer fluid, heavy-duty blades'),
    ],
  ),
  SeasonalGroupTemplate(
    id: 'spring_summer',
    name: 'Spring / Summer',
    season: 'Spring',
    activeMonths: [3, 4, 5, 6, 7],
    icon: Icons.wb_sunny,
    tasks: [
      SeasonalTaskTemplate(id: 'ac_system', label: 'A/C system check', tip: 'Verify cold output, check for leaks'),
      SeasonalTaskTemplate(id: 'cabin_filter', label: 'Replace cabin air filter', tip: 'Usually behind glove box. Replace annually.'),
      SeasonalTaskTemplate(id: 'alignment', label: 'Alignment check', tip: 'Especially after winter potholes'),
    ],
  ),
  SeasonalGroupTemplate(
    id: 'body_care',
    name: 'Body & Exterior Care',
    season: 'Year-round',
    activeMonths: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    icon: Icons.auto_awesome,
    tasks: [
      SeasonalTaskTemplate(id: 'undercarriage_wash', label: 'Undercarriage wash (salt)', tip: 'Critical after winter salt exposure'),
      SeasonalTaskTemplate(id: 'wax_sealant', label: 'Wax or paint sealant', tip: 'Every 3-6 months for UV and salt protection'),
      SeasonalTaskTemplate(id: 'bed_liner', label: 'Inspect bed liner & tailgate', tip: 'Check for chips, rust spots under liner'),
    ],
  ),
];

/// Lookup seasonal group by id.
SeasonalGroupTemplate? getSeasonalGroup(String id) {
  for (final g in kSeasonalGroups) {
    if (g.id == id) return g;
  }
  return null;
}
