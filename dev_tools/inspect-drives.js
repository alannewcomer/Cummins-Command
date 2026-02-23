#!/usr/bin/env node
// inspect-drives.js — List all drives across all users/vehicles with key stats.
//
// Usage:
//   node dev_tools/inspect-drives.js                  # all drives
//   node dev_tools/inspect-drives.js --limit 5        # last 5 drives
//   node dev_tools/inspect-drives.js --uid <userId>   # specific user

const { db } = require('./firestore-init');

async function main() {
  const args = process.argv.slice(2);
  const limitIdx = args.indexOf('--limit');
  const limit = limitIdx >= 0 ? parseInt(args[limitIdx + 1], 10) : 100;
  const uidIdx = args.indexOf('--uid');
  const filterUid = uidIdx >= 0 ? args[uidIdx + 1] : null;

  console.log('\n=== CUMMINS COMMAND — DRIVE INSPECTOR ===\n');

  // Find all users (or specific one)
  // Note: User docs may not "exist" (no data) but still have subcollections.
  // Use listDocuments() to find container docs with subcollections.
  let userRefs;
  if (filterUid) {
    userRefs = [db.collection('users').doc(filterUid)];
  } else {
    // listDocuments() finds docs even if they have no fields (just subcollections)
    userRefs = await db.collection('users').listDocuments();
    if (userRefs.length === 0) {
      // Fallback: try .get() in case listDocuments misses anything
      const snap = await db.collection('users').get();
      userRefs = snap.docs.map(d => d.ref);
    }
  }

  console.log(`Found ${userRefs.length} user(s)\n`);

  let totalDrives = 0;

  for (const userRef of userRefs) {
    const uid = userRef.id;
    console.log(`--- User: ${uid} ---`);

    const vehiclesSnap = await db
      .collection('users').doc(uid)
      .collection('vehicles').get();

    for (const vDoc of vehiclesSnap.docs) {
      const vid = vDoc.id;
      const vData = vDoc.data();
      console.log(`  Vehicle: ${vData.year || '?'} ${vData.make || '?'} ${vData.model || ''} (${vid})`);

      const drivesSnap = await db
        .collection('users').doc(uid)
        .collection('vehicles').doc(vid)
        .collection('drives')
        .orderBy('startTime', 'desc')
        .limit(limit)
        .get();

      if (drivesSnap.empty) {
        console.log('    No drives found.\n');
        continue;
      }

      console.log(`    ${drivesSnap.size} drive(s):\n`);

      console.log('    ' + [
        'Drive ID'.padEnd(22),
        'Date'.padEnd(22),
        'Dur'.padEnd(8),
        'Dist'.padEnd(8),
        'MPG'.padEnd(6),
        'Status'.padEnd(18),
        'Health'.padEnd(7),
        'MaxBoost'.padEnd(9),
        'MaxEGT'.padEnd(8),
        'MaxTrans'.padEnd(9),
      ].join(' '));
      console.log('    ' + '-'.repeat(130));

      for (const dDoc of drivesSnap.docs) {
        const d = dDoc.data();
        const maxs = d.maximums || {};
        const startTime = d.startTime?.toDate?.() || null;
        const dateStr = startTime
          ? startTime.toISOString().replace('T', ' ').slice(0, 19)
          : 'unknown';
        const dur = d.durationSeconds || 0;
        const durStr = dur >= 3600
          ? `${Math.floor(dur / 3600)}h${Math.floor((dur % 3600) / 60)}m`
          : `${Math.floor(dur / 60)}m${dur % 60}s`;

        console.log('    ' + [
          dDoc.id.padEnd(22),
          dateStr.padEnd(22),
          durStr.padEnd(8),
          `${(d.distanceMiles || 0).toFixed(1)}mi`.padEnd(8),
          (d.averageMPG || 0).toFixed(1).padEnd(6),
          (d.status || '?').padEnd(18),
          String(d.aiHealthScore ?? '-').padEnd(7),
          maxs.maxBoostPsi != null ? `${maxs.maxBoostPsi.toFixed(0)}psi` : '-'.padEnd(6),
          (maxs.maxEgtF != null ? `${maxs.maxEgtF.toFixed(0)}°F` : '-').padEnd(8),
          (maxs.maxTransTempF != null ? `${maxs.maxTransTempF.toFixed(0)}°F` : '-').padEnd(9),
        ].join(' '));

        totalDrives++;
      }
      console.log('');
    }
  }

  console.log(`\nTotal: ${totalDrives} drive(s) inspected.\n`);
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
