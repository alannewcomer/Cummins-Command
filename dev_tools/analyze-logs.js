#!/usr/bin/env node
// analyze-logs.js — Analyze recent devLogs for protocol detection, PID issues, and errors.

const { db } = require('./firestore-init');

async function main() {
  const uid = 'RQbMnYutsJhreGsSbjBuG4oJz1E2';

  const allLogs = await db.collection('users').doc(uid)
    .collection('devLogs')
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();

  console.log('Fetched', allLogs.size, 'log docs\n');

  const recentEntries = [];
  for (const doc of allLogs.docs.slice(0, 20)) {
    const data = doc.data();
    const entries = data.entries || [];
    for (const e of entries) {
      recentEntries.push(e);
    }
  }

  console.log('Recent entries:', recentEntries.length);

  // Protocol detection
  console.log('\n=== PROTOCOL DETECTION ===');
  for (const e of recentEntries) {
    const msg = e.msg || '';
    if (msg.includes('rotocol') || msg.includes('Trying') || msg.includes('ATSP') ||
        msg.includes('Probe') || msg.includes('confirmed') || msg.includes('DUAL') ||
        msg.includes('bitmap') || msg.includes('OBD ready') || msg.includes('Adapter switch') ||
        msg.includes('J1939') || msg.includes('detected') || msg.includes('Supported PID') ||
        msg.includes('Total supported') || msg.includes('OBD2 confirmed') ||
        msg.includes('detection complete') || msg.includes('Probing')) {
      const ts = new Date(e.t).toISOString().slice(11, 19);
      console.log(ts, e.level.padEnd(5), e.msg);
      if (e.detail) console.log('        ', e.detail.slice(0, 250));
    }
  }

  // Polling summary
  console.log('\n=== POLL SUMMARIES ===');
  for (const e of recentEntries) {
    if (e.msg && (e.msg.includes('Poll summary') || e.msg.includes('Live sensors') ||
        e.msg.includes('Disabled PIDs') || e.msg.includes('Polling started'))) {
      const ts = new Date(e.t).toISOString().slice(11, 19);
      console.log(ts, e.level.padEnd(5), e.msg);
      if (e.detail) console.log('        ', e.detail.slice(0, 300));
    }
  }

  // First successes
  console.log('\n=== FIRST PID SUCCESSES ===');
  for (const e of recentEntries) {
    if (e.msg && e.msg.includes('first success')) {
      const ts = new Date(e.t).toISOString().slice(11, 19);
      console.log(ts, e.level.padEnd(5), e.msg);
      if (e.detail) console.log('        ', e.detail.slice(0, 200));
    }
  }

  // PID failures (deduplicated by PID name)
  console.log('\n=== PID FAILURES (first occurrence per PID) ===');
  const seenPids = new Set();
  for (const e of recentEntries) {
    if (e.tag === 'PID' && e.msg &&
        (e.msg.includes('negative_resp') || e.msg.includes('no_response') ||
         e.msg.includes('parse_fail') || e.msg.includes('disabled'))) {
      const pidMatch = e.msg.match(/[✗✓] (\w+)/);
      const pid = pidMatch ? pidMatch[1] : 'unknown';
      if (!seenPids.has(pid)) {
        seenPids.add(pid);
        const ts = new Date(e.t).toISOString().slice(11, 19);
        console.log(ts, e.level.padEnd(5), e.msg);
        if (e.detail) console.log('        ', e.detail.slice(0, 250));
      }
    }
  }

  // Aggregate PID error counts
  console.log('\n=== PID ERROR SUMMARY ===');
  const pidErrors = {};
  for (const e of recentEntries) {
    if (e.tag === 'PID' && e.msg) {
      const pidMatch = e.msg.match(/[✗✓] (\w+)/);
      if (pidMatch) {
        const pid = pidMatch[1];
        pidErrors[pid] = pidErrors[pid] || { success: 0, no_response: 0, negative_resp: 0, parse_fail: 0, disabled: 0 };
        if (e.msg.includes('first success') || e.msg.includes('= ')) pidErrors[pid].success++;
        if (e.msg.includes('no_response')) pidErrors[pid].no_response++;
        if (e.msg.includes('negative_resp')) pidErrors[pid].negative_resp++;
        if (e.msg.includes('parse_fail')) pidErrors[pid].parse_fail++;
        if (e.msg.includes('disabled')) pidErrors[pid].disabled++;
      }
    }
  }

  console.log('PID'.padEnd(28), 'OK'.padEnd(6), 'NoResp'.padEnd(8), 'NegResp'.padEnd(9), 'Parse'.padEnd(7), 'Disabled');
  console.log('-'.repeat(70));
  const sorted = Object.entries(pidErrors).sort((a, b) => {
    const totalA = a[1].no_response + a[1].negative_resp + a[1].parse_fail;
    const totalB = b[1].no_response + b[1].negative_resp + b[1].parse_fail;
    return totalB - totalA;
  });
  for (const [pid, errs] of sorted) {
    console.log(
      pid.padEnd(28),
      String(errs.success).padEnd(6),
      String(errs.no_response).padEnd(8),
      String(errs.negative_resp).padEnd(9),
      String(errs.parse_fail).padEnd(7),
      String(errs.disabled)
    );
  }

  // Other errors
  console.log('\n=== OTHER ERRORS ===');
  for (const e of recentEntries) {
    if (e.level === 'error' && e.tag !== 'PID') {
      const ts = new Date(e.t).toISOString().slice(11, 19);
      console.log(ts, e.level.padEnd(5), e.tag, e.msg);
      if (e.detail) console.log('        ', e.detail.slice(0, 200));
    }
  }

  // Drive recorder events
  console.log('\n=== DRIVE RECORDER EVENTS ===');
  for (const e of recentEntries) {
    if (e.tag === 'REC') {
      const ts = new Date(e.t).toISOString().slice(11, 19);
      console.log(ts, e.level.padEnd(5), e.msg);
      if (e.detail) console.log('        ', e.detail.slice(0, 300));
    }
  }

  // Command state errors count
  let cmdStateErrors = 0;
  let cmdTimeouts = 0;
  for (const e of recentEntries) {
    if (e.msg === 'Command state error') cmdStateErrors++;
    if (e.msg === 'Command timeout') cmdTimeouts++;
    if (e.msg === 'Command lock timeout') cmdTimeouts++;
  }
  console.log('\n=== COMMAND ISSUES ===');
  console.log('Command state errors:', cmdStateErrors);
  console.log('Command timeouts:', cmdTimeouts);
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
