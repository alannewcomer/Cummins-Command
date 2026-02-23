#!/usr/bin/env node
// timeline-logs.js — Full chronological timeline of recent logs.

const { db } = require('./firestore-init');

async function main() {
  const uid = 'RQbMnYutsJhreGsSbjBuG4oJz1E2';
  const allLogs = await db.collection('users').doc(uid)
    .collection('devLogs')
    .orderBy('createdAt', 'desc')
    .limit(80)
    .get();

  const entries = [];
  for (const doc of allLogs.docs) {
    const data = doc.data();
    for (const e of (data.entries || [])) entries.push(e);
  }

  // Sort by timestamp
  entries.sort((a, b) => a.t - b.t);

  console.log('Total entries:', entries.length);
  if (entries.length === 0) return;
  console.log('Time range:', new Date(entries[0].t).toISOString(), '→', new Date(entries[entries.length - 1].t).toISOString());

  console.log('\n=== FULL TIMELINE (key events) ===');
  for (const e of entries) {
    const msg = e.msg || '';
    const tag = e.tag || '';
    // Skip routine noise
    if (msg.includes('Flushed') && msg.indexOf('error') === -1) continue;
    if (msg.includes('Recording:')) continue;
    if (tag === 'PID' && msg.indexOf('first') === -1 && msg.indexOf('disabled') === -1 && msg.indexOf('J1939') === -1) continue;

    const ts = new Date(e.t).toISOString().slice(11, 23);
    const detail = e.detail ? '  ' + e.detail.slice(0, 300) : '';
    console.log(ts, e.level.padEnd(5), (tag || '').padEnd(6), msg + detail);
  }
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
