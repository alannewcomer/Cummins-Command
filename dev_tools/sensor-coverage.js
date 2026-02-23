#!/usr/bin/env node
// sensor-coverage.js — Aggregate sensor coverage across ALL drives.
//
// For each sensor, shows how many drives have that data and overall health.
// This tells you which PIDs are actually making it from OBD → Firestore.
//
// Usage:
//   node dev_tools/sensor-coverage.js                 # full scan
//   node dev_tools/sensor-coverage.js --limit 10      # last 10 drives only
//   node dev_tools/sensor-coverage.js --uid <userId>   # specific user

const { db } = require('./firestore-init');

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

// PID config grouping for reporting
const PID_GROUPS = {
  'Core Engine':    ['rpm', 'speed', 'engineLoad', 'throttlePos', 'maf'],
  'Temperatures':   ['coolantTemp', 'intakeTemp', 'oilTemp', 'transTemp', 'intercoolerOutletTemp', 'ambientTemp'],
  'EGT Probes':     ['egt', 'egt2', 'egt3', 'egt4'],
  'Boost/Turbo':    ['boostPressure', 'turboSpeed', 'vgtPosition'],
  'Fuel System':    ['fuelRate', 'fuelLevel', 'instantMPG', 'railPressure', 'railPressureActual'],
  'Pressures':      ['oilPressure', 'crankcasePressure', 'exhaustBackpressure', 'barometric'],
  'DPF/Emissions':  ['dpfSootLoad', 'dpfRegenStatus', 'dpfDiffPressure', 'noxPreScr', 'noxPostScr'],
  'DEF System':     ['defLevel', 'defTemp', 'defDosingRate', 'defQuality'],
  'Drivetrain':     ['transGearActual', 'transGearCmd', 'tcLockStatus', 'estimatedGear'],
  'GPS':            ['lat', 'lng', 'altitude', 'gpsSpeed', 'heading'],
  'System':         ['batteryVoltage', 'coolantLevel', 'odometer', 'engineHours', 'egrPosition'],
  'Calculated':     ['estimatedHP', 'estimatedTorque'],
};

async function main() {
  const args = process.argv.slice(2);
  const limitIdx = args.indexOf('--limit');
  const driveLimit = limitIdx >= 0 ? parseInt(args[limitIdx + 1], 10) : 999;
  const uidIdx = args.indexOf('--uid');
  const filterUid = uidIdx >= 0 ? args[uidIdx + 1] : null;

  console.log('\n=== CUMMINS COMMAND — SENSOR COVERAGE MATRIX ===\n');

  // Collect all drives
  const drives = []; // { uid, vid, did, date, datapoints }
  let userRefs;
  if (filterUid) {
    userRefs = [db.collection('users').doc(filterUid)];
  } else {
    userRefs = await db.collection('users').listDocuments();
    if (userRefs.length === 0) {
      const snap = await db.collection('users').get();
      userRefs = snap.docs.map(d => d.ref);
    }
  }

  for (const userRef of userRefs) {
    const uid = userRef.id;
    const vehiclesSnap = await db
      .collection('users').doc(uid)
      .collection('vehicles').get();

    for (const vDoc of vehiclesSnap.docs) {
      const vid = vDoc.id;
      const drivesSnap = await db
        .collection('users').doc(uid)
        .collection('vehicles').doc(vid)
        .collection('drives')
        .orderBy('startTime', 'desc')
        .limit(driveLimit)
        .get();

      for (const dDoc of drivesSnap.docs) {
        const d = dDoc.data();
        drives.push({
          uid, vid, did: dDoc.id,
          date: d.startTime?.toDate?.() || null,
          status: d.status || '?',
        });
      }
    }
  }

  console.log(`Found ${drives.length} drive(s) to scan.\n`);
  if (drives.length === 0) return;

  // Per-sensor tracking
  const sensorStats = {};
  for (const field of ALL_SENSOR_FIELDS) {
    sensorStats[field] = {
      drivesWithData: 0,
      totalPoints: 0,
      totalPointsAcrossDrives: 0, // total dp count across drives that have this sensor
      globalMin: Infinity,
      globalMax: -Infinity,
    };
  }

  let totalDatapoints = 0;

  // Process each drive
  for (let i = 0; i < drives.length; i++) {
    const drv = drives[i];
    const dateStr = drv.date ? drv.date.toISOString().slice(0, 10) : '?';
    process.stdout.write(`  Scanning drive ${i + 1}/${drives.length} (${dateStr})...`);

    // Sample first 50 + last 50 datapoints for speed (instead of reading all)
    // For full accuracy, read all — but for a quick scan this is sufficient
    const dpSnap = await db
      .collection('users').doc(drv.uid)
      .collection('vehicles').doc(drv.vid)
      .collection('drives').doc(drv.did)
      .collection('datapoints')
      .orderBy('timestamp')
      .get();

    const dpCount = dpSnap.size;
    totalDatapoints += dpCount;
    process.stdout.write(` ${dpCount} datapoints`);

    if (dpCount === 0) {
      process.stdout.write(' (EMPTY)\n');
      continue;
    }

    // Check which sensors have data in this drive
    const driveSensorCounts = {};
    for (const field of ALL_SENSOR_FIELDS) {
      driveSensorCounts[field] = 0;
    }

    for (const doc of dpSnap.docs) {
      const d = doc.data();
      for (const field of ALL_SENSOR_FIELDS) {
        const v = d[field];
        if (v !== undefined && v !== null) {
          driveSensorCounts[field]++;
          const s = sensorStats[field];
          s.totalPoints++;
          if (v < s.globalMin) s.globalMin = v;
          if (v > s.globalMax) s.globalMax = v;
        }
      }
    }

    let sensorsPresent = 0;
    for (const field of ALL_SENSOR_FIELDS) {
      if (driveSensorCounts[field] > 0) {
        sensorStats[field].drivesWithData++;
        sensorStats[field].totalPointsAcrossDrives += dpCount;
        sensorsPresent++;
      }
    }

    process.stdout.write(` → ${sensorsPresent} sensors active\n`);
  }

  // Print results
  console.log(`\n${'='.repeat(130)}`);
  console.log('SENSOR COVERAGE MATRIX');
  console.log(`${'='.repeat(130)}`);
  console.log(`Scanned ${drives.length} drives, ${totalDatapoints} total datapoints\n`);

  for (const [group, fields] of Object.entries(PID_GROUPS)) {
    const groupPresent = fields.filter(f => sensorStats[f].drivesWithData > 0).length;
    const groupIcon = groupPresent === 0 ? 'NONE' :
      groupPresent === fields.length ? ' OK ' : 'PART';

    console.log(`\n  [${groupIcon}] ${group}:`);
    console.log('  ' + [
      'Sensor'.padEnd(26),
      'Drives'.padEnd(10),
      'Coverage'.padEnd(10),
      'Total Pts'.padEnd(12),
      'Avg Fill%'.padEnd(10),
      'Global Min'.padEnd(12),
      'Global Max'.padEnd(12),
      'Status',
    ].join(' '));
    console.log('  ' + '-'.repeat(110));

    for (const field of fields) {
      const s = sensorStats[field];
      const drivePct = drives.length > 0
        ? ((s.drivesWithData / drives.length) * 100).toFixed(0)
        : '0';
      const avgFill = s.totalPointsAcrossDrives > 0
        ? ((s.totalPoints / s.totalPointsAcrossDrives) * 100).toFixed(0)
        : '0';

      let status;
      if (s.drivesWithData === 0) {
        status = 'MISSING — never recorded';
      } else if (parseInt(drivePct) < 50) {
        status = 'SPARSE — intermittent';
      } else if (parseInt(avgFill) < 50) {
        status = 'LOW FILL — gaps in data';
      } else {
        status = 'GOOD';
      }

      const bar = makeBar(parseInt(drivePct));

      console.log('  ' + [
        field.padEnd(26),
        `${s.drivesWithData}/${drives.length}`.padEnd(10),
        `${drivePct}% ${bar}`.padEnd(10),
        String(s.totalPoints).padEnd(12),
        `${avgFill}%`.padEnd(10),
        fmtNum(s.globalMin).padEnd(12),
        fmtNum(s.globalMax).padEnd(12),
        status,
      ].join(' '));
    }
  }

  // Summary: sensors never recorded
  const neverRecorded = ALL_SENSOR_FIELDS.filter(f => sensorStats[f].drivesWithData === 0);
  if (neverRecorded.length > 0) {
    console.log(`\n${'='.repeat(130)}`);
    console.log(`SENSORS NEVER RECORDED (${neverRecorded.length}):`);
    console.log(`${'='.repeat(130)}`);
    for (const f of neverRecorded) {
      console.log(`  - ${f}`);
    }
    console.log('\nThese sensors are defined in DataPoint model but have NEVER appeared');
    console.log('in any Firestore datapoint document. Possible causes:');
    console.log('  1. PID not supported by ECU (check OBD service PID bitmap)');
    console.log('  2. PID fails to parse (check diagnostic logs for parse_fail)');
    console.log('  3. PID disabled after too many consecutive failures');
    console.log('  4. Wrong protocol (OBD2 vs J1939 vs Mode $22)');
    console.log('  5. Feature not yet implemented (GPS, estimatedHP, etc.)');
  }

  console.log('');
}

function fmtNum(v) {
  if (v === Infinity || v === -Infinity) return '-';
  if (Number.isInteger(v)) return String(v);
  return v.toFixed(2);
}

function makeBar(pct) {
  const filled = Math.round(pct / 10);
  return '[' + '#'.repeat(filled) + '.'.repeat(10 - filled) + ']';
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
