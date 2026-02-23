#!/usr/bin/env node
// inspect-datapoints.js — Deep sensor coverage report for a specific drive.
//
// Shows which sensors have data, value ranges, null rates, and sample timestamps.
//
// Usage:
//   node dev_tools/inspect-datapoints.js <uid> <vehicleId> <driveId>
//   node dev_tools/inspect-datapoints.js --find-latest              # auto-find latest drive
//   node dev_tools/inspect-datapoints.js --find-latest --sample 5   # show 5 sample values per sensor

const { db } = require('./firestore-init');

// All known datapoint fields (from datapoint.dart)
const ALL_SENSOR_FIELDS = [
  'rpm', 'speed', 'coolantTemp', 'intakeTemp', 'maf', 'throttlePos',
  'boostPressure', 'egt', 'egt2', 'egt3', 'egt4', 'transTemp',
  'oilTemp', 'oilPressure', 'engineLoad', 'turboSpeed', 'vgtPosition',
  'egrPosition', 'dpfSootLoad', 'dpfRegenStatus', 'dpfDiffPressure',
  'noxPreScr', 'noxPostScr', 'defLevel', 'defTemp', 'defDosingRate',
  'defQuality', 'railPressure', 'railPressureActual', 'crankcasePressure',
  'coolantLevel', 'intercoolerOutletTemp', 'exhaustBackpressure',
  'fuelRate', 'fuelLevel', 'batteryVoltage', 'ambientTemp', 'barometric',
  'odometer', 'engineHours', 'transGearActual', 'transGearCmd',
  'tcLockStatus', 'lat', 'lng', 'altitude', 'gpsSpeed', 'heading',
  'instantMPG', 'estimatedGear', 'estimatedHP', 'estimatedTorque',
];

async function findLatestDrive() {
  const userRefs = await db.collection('users').listDocuments();
  for (const userRef of userRefs) {
    const vehiclesSnap = await db
      .collection('users').doc(userRef.id)
      .collection('vehicles').get();
    for (const vDoc of vehiclesSnap.docs) {
      const drivesSnap = await db
        .collection('users').doc(userRef.id)
        .collection('vehicles').doc(vDoc.id)
        .collection('drives')
        .orderBy('startTime', 'desc')
        .limit(1)
        .get();
      if (!drivesSnap.empty) {
        return {
          uid: userRef.id,
          vid: vDoc.id,
          did: drivesSnap.docs[0].id,
          drive: drivesSnap.docs[0].data(),
        };
      }
    }
  }
  return null;
}

async function main() {
  const args = process.argv.slice(2);
  const sampleIdx = args.indexOf('--sample');
  const sampleCount = sampleIdx >= 0 ? parseInt(args[sampleIdx + 1], 10) : 3;

  let uid, vid, did, driveData;

  if (args.includes('--find-latest')) {
    console.log('\nSearching for latest drive...');
    const found = await findLatestDrive();
    if (!found) {
      console.log('No drives found in Firestore.');
      return;
    }
    uid = found.uid;
    vid = found.vid;
    did = found.did;
    driveData = found.drive;
  } else if (args.length >= 3 && !args[0].startsWith('--')) {
    uid = args[0];
    vid = args[1];
    did = args[2];
    const driveDoc = await db
      .collection('users').doc(uid)
      .collection('vehicles').doc(vid)
      .collection('drives').doc(did).get();
    driveData = driveDoc.exists ? driveDoc.data() : null;
  } else {
    console.log('Usage:');
    console.log('  node dev_tools/inspect-datapoints.js <uid> <vehicleId> <driveId>');
    console.log('  node dev_tools/inspect-datapoints.js --find-latest');
    console.log('  node dev_tools/inspect-datapoints.js --find-latest --sample 5');
    return;
  }

  console.log('\n=== DATAPOINT SENSOR COVERAGE REPORT ===\n');
  console.log(`Path: users/${uid}/vehicles/${vid}/drives/${did}/datapoints`);

  if (driveData) {
    const start = driveData.startTime?.toDate?.();
    console.log(`Drive: ${start ? start.toISOString().slice(0, 19) : '?'}`);
    console.log(`Duration: ${driveData.durationSeconds || 0}s | Distance: ${(driveData.distanceMiles || 0).toFixed(1)}mi | Status: ${driveData.status}`);
  }

  // Load ALL datapoints
  console.log('\nLoading datapoints...');
  const dpSnap = await db
    .collection('users').doc(uid)
    .collection('vehicles').doc(vid)
    .collection('drives').doc(did)
    .collection('datapoints')
    .orderBy('timestamp')
    .get();

  const totalDp = dpSnap.size;
  console.log(`Total datapoints: ${totalDp}\n`);

  if (totalDp === 0) {
    console.log('NO DATAPOINTS FOUND. The drive has no sensor data recorded.');
    return;
  }

  // Timestamps
  const firstDp = dpSnap.docs[0].data();
  const lastDp = dpSnap.docs[dpSnap.size - 1].data();
  const startMs = firstDp.timestamp;
  const endMs = lastDp.timestamp;
  const spanSec = ((endMs - startMs) / 1000).toFixed(1);
  const avgIntervalMs = totalDp > 1 ? ((endMs - startMs) / (totalDp - 1)).toFixed(0) : 0;

  console.log(`Time span: ${spanSec}s (${(spanSec / 60).toFixed(1)} min)`);
  console.log(`First timestamp: ${new Date(startMs).toISOString()}`);
  console.log(`Last timestamp:  ${new Date(endMs).toISOString()}`);
  console.log(`Avg interval: ${avgIntervalMs}ms (${(avgIntervalMs / 1000).toFixed(1)}s)`);

  // Analyze each field
  const stats = {};
  for (const field of ALL_SENSOR_FIELDS) {
    stats[field] = {
      count: 0,
      min: Infinity,
      max: -Infinity,
      sum: 0,
      samples: [],
    };
  }

  // Track all unknown fields too
  const unknownFields = new Set();

  for (const doc of dpSnap.docs) {
    const d = doc.data();
    for (const field of ALL_SENSOR_FIELDS) {
      const v = d[field];
      if (v !== undefined && v !== null) {
        const s = stats[field];
        s.count++;
        if (v < s.min) s.min = v;
        if (v > s.max) s.max = v;
        s.sum += v;
        if (s.samples.length < sampleCount) {
          s.samples.push(v);
        }
      }
    }
    // Check for unknown fields
    for (const key of Object.keys(d)) {
      if (key !== 'timestamp' && !ALL_SENSOR_FIELDS.includes(key)) {
        unknownFields.add(key);
      }
    }
  }

  // Categorize sensors
  const populated = [];
  const empty = [];

  for (const field of ALL_SENSOR_FIELDS) {
    const s = stats[field];
    if (s.count > 0) {
      populated.push({
        field,
        count: s.count,
        pct: ((s.count / totalDp) * 100).toFixed(1),
        min: s.min,
        max: s.max,
        avg: (s.sum / s.count),
        samples: s.samples,
      });
    } else {
      empty.push(field);
    }
  }

  // Sort populated by coverage descending
  populated.sort((a, b) => b.count - a.count);

  // Print populated sensors
  console.log(`\n${'='.repeat(120)}`);
  console.log(`SENSORS WITH DATA (${populated.length}/${ALL_SENSOR_FIELDS.length}):`);
  console.log(`${'='.repeat(120)}`);

  console.log([
    'Sensor'.padEnd(26),
    'Count'.padEnd(8),
    'Coverage'.padEnd(10),
    'Min'.padEnd(12),
    'Max'.padEnd(12),
    'Avg'.padEnd(12),
    'Samples',
  ].join(' '));
  console.log('-'.repeat(120));

  for (const s of populated) {
    const bar = '|' + '#'.repeat(Math.round(parseFloat(s.pct) / 5)) + '.'.repeat(20 - Math.round(parseFloat(s.pct) / 5)) + '|';
    console.log([
      s.field.padEnd(26),
      String(s.count).padEnd(8),
      `${s.pct}%`.padEnd(10),
      formatNum(s.min).padEnd(12),
      formatNum(s.max).padEnd(12),
      formatNum(s.avg).padEnd(12),
      s.samples.map(v => formatNum(v)).join(', '),
    ].join(' '));
  }

  // Print empty sensors
  console.log(`\n${'='.repeat(120)}`);
  console.log(`SENSORS WITH NO DATA (${empty.length}/${ALL_SENSOR_FIELDS.length}):`);
  console.log(`${'='.repeat(120)}`);

  // Group by category
  const categories = {
    'Core Engine': ['rpm', 'speed', 'engineLoad', 'throttlePos', 'maf'],
    'Temperatures': ['coolantTemp', 'intakeTemp', 'oilTemp', 'transTemp', 'intercoolerOutletTemp', 'ambientTemp'],
    'EGT Probes': ['egt', 'egt2', 'egt3', 'egt4'],
    'Boost/Turbo': ['boostPressure', 'turboSpeed', 'vgtPosition'],
    'Fuel': ['fuelRate', 'fuelLevel', 'instantMPG', 'railPressure', 'railPressureActual'],
    'Pressures': ['oilPressure', 'crankcasePressure', 'exhaustBackpressure', 'barometric'],
    'DPF/Emissions': ['dpfSootLoad', 'dpfRegenStatus', 'dpfDiffPressure', 'noxPreScr', 'noxPostScr'],
    'DEF': ['defLevel', 'defTemp', 'defDosingRate', 'defQuality'],
    'Drivetrain': ['transGearActual', 'transGearCmd', 'tcLockStatus', 'estimatedGear'],
    'GPS': ['lat', 'lng', 'altitude', 'gpsSpeed', 'heading'],
    'System': ['batteryVoltage', 'coolantLevel', 'odometer', 'engineHours', 'egrPosition'],
    'Calculated': ['estimatedHP', 'estimatedTorque'],
  };

  for (const [cat, fields] of Object.entries(categories)) {
    const missing = fields.filter(f => empty.includes(f));
    const present = fields.filter(f => !empty.includes(f));
    if (missing.length === 0) continue;

    const statusIcon = present.length === 0 ? 'NONE' :
      missing.length > 0 ? 'PARTIAL' : 'OK';

    console.log(`\n  [${statusIcon}] ${cat}:`);
    for (const f of missing) {
      console.log(`    - ${f}`);
    }
    if (present.length > 0) {
      console.log(`    (has: ${present.join(', ')})`);
    }
  }

  // Unknown fields
  if (unknownFields.size > 0) {
    console.log(`\n${'='.repeat(120)}`);
    console.log(`UNKNOWN FIELDS (found in datapoints but not in schema):`);
    console.log(`${'='.repeat(120)}`);
    for (const f of unknownFields) {
      console.log(`  - ${f}`);
    }
  }

  // Summary
  const coveragePct = ((populated.length / ALL_SENSOR_FIELDS.length) * 100).toFixed(0);
  console.log(`\n${'='.repeat(120)}`);
  console.log(`SUMMARY`);
  console.log(`${'='.repeat(120)}`);
  console.log(`Total datapoints:    ${totalDp}`);
  console.log(`Time span:           ${spanSec}s (${(spanSec / 60).toFixed(1)} min)`);
  console.log(`Avg sample interval: ${avgIntervalMs}ms`);
  console.log(`Sensors with data:   ${populated.length}/${ALL_SENSOR_FIELDS.length} (${coveragePct}%)`);
  console.log(`Sensors empty:       ${empty.length}/${ALL_SENSOR_FIELDS.length}`);
  console.log('');
}

function formatNum(v) {
  if (v === Infinity || v === -Infinity) return '-';
  if (Number.isInteger(v)) return String(v);
  return v.toFixed(2);
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
