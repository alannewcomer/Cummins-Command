const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { readTimeseries } = require('./lib/timeseries');
const { callGeminiPro, callGeminiFlash } = require('./lib/gemini');
const { paths, USERS, VEHICLES, DRIVES, DATAPOINTS, MAINTENANCE, AI_JOBS, SHARING } = require('./lib/firestore-paths');
const {
  buildDriveAnalysisPrompt,
  buildRangeAnalysisPrompt,
  buildMaintenancePredictionPrompt,
  buildCustomQueryPrompt,
  buildDashboardPrompt,
  buildBaselinePrompt,
} = require('./lib/prompts');

initializeApp();
const db = getFirestore();

// ──────────────────────────────────────────────────────────────
// 1. analyzeDrive — triggered when timeseriesUploaded flips to true
// ──────────────────────────────────────────────────────────────
exports.analyzeDrive = onDocumentUpdated(
  `${USERS}/{uid}/${VEHICLES}/{vid}/${DRIVES}/{did}`,
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after) return;

    // Only trigger when timeseriesUploaded flips to true
    if (before.timeseriesUploaded || !after.timeseriesUploaded) return;
    // Don't re-analyze
    if (after.aiSummary) return;

    const { uid, vid, did } = event.params;
    const driveRef = event.data.after.ref;

    try {
      // Read vehicle doc
      const vehicleSnap = await db.doc(paths.vehicle(uid, vid)).get();
      const vehicle = vehicleSnap.data() || {};

      const drive = { id: did, ...after };

      // Use parameterStats from drive doc — no need to download timeseries file
      const stats = aggregateDriveStats(drive, after.parameterStats || {});

      // Call Gemini 3.1 Pro
      const analysis = await callGeminiPro(
        buildDriveAnalysisPrompt(vehicle, drive, stats),
        'low'
      );

      // Write results back to drive doc
      await driveRef.update({
        aiSummary: analysis.summary || '',
        aiAnomalies: analysis.anomalies || [],
        aiHealthScore: analysis.healthScore || 0,
        aiRecommendations: analysis.recommendations || [],
        aiAnalyzedAt: FieldValue.serverTimestamp(),
        status: 'analysisComplete',
      });
    } catch (err) {
      console.error(`analyzeDrive failed for ${did}:`, err);
      await driveRef.update({
        aiError: err.message,
        aiAnalyzedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

// ──────────────────────────────────────────────────────────────
// 2. processAiJob — dispatches AI job requests by type
// ──────────────────────────────────────────────────────────────
exports.processAiJob = onDocumentCreated(
  `${USERS}/{uid}/${AI_JOBS}/{jobId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const job = snap.data();
    const { uid, jobId } = event.params;
    const jobType = job.type;

    // Skip types handled by dedicated functions
    if (jobType === 'dashboard_generation' || jobType === 'export') return;

    try {
      await snap.ref.update({ status: 'processing', progress: 0.1 });

      const vid = job.vehicleId;
      const vehicleSnap = await db.doc(paths.vehicle(uid, vid)).get();
      const vehicle = vehicleSnap.data() || {};

      let result;

      if (jobType === 'range_analysis') {
        await snap.ref.update({ progress: 0.3 });
        const drivesSnap = await db
          .collection(paths.vehicle(uid, vid) + `/${DRIVES}`)
          .where('startTime', '>=', job.params?.startDate || '')
          .where('startTime', '<=', job.params?.endDate || '')
          .orderBy('startTime')
          .get();
        const drives = drivesSnap.docs.map(d => ({ id: d.id, ...d.data() }));

        await snap.ref.update({ progress: 0.5 });
        result = await callGeminiPro(
          buildRangeAnalysisPrompt(vehicle, drives, job.params || {}),
          'high'
        );

      } else if (jobType === 'predictive_maintenance') {
        await snap.ref.update({ progress: 0.3 });
        const drivesSnap = await db
          .collection(paths.vehicle(uid, vid) + `/${DRIVES}`)
          .orderBy('startTime', 'desc')
          .limit(30)
          .get();
        const drives = drivesSnap.docs.map(d => ({ id: d.id, ...d.data() }));

        const maintSnap = await db
          .collection(paths.maintenance(uid, vid))
          .orderBy('date', 'desc')
          .get();
        const maintenance = maintSnap.docs.map(d => d.data());

        await snap.ref.update({ progress: 0.5 });
        result = await callGeminiPro(
          buildMaintenancePredictionPrompt(vehicle, drives, maintenance),
          'high'
        );

      } else if (jobType === 'custom_query') {
        await snap.ref.update({ progress: 0.3 });
        const drivesSnap = await db
          .collection(paths.vehicle(uid, vid) + `/${DRIVES}`)
          .orderBy('startTime', 'desc')
          .limit(20)
          .get();
        const drives = drivesSnap.docs.map(d => ({ id: d.id, ...d.data() }));

        await snap.ref.update({ progress: 0.5 });
        result = await callGeminiPro(
          buildCustomQueryPrompt(vehicle, drives, job.params || {}),
          'high'
        );

      } else {
        throw new Error(`Unknown AI job type: ${jobType}`);
      }

      await snap.ref.update({
        status: 'completed',
        progress: 1.0,
        result,
        completedAt: FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`processAiJob failed for ${jobId}:`, err);
      await snap.ref.update({
        status: 'error',
        error: err.message,
        completedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

// ──────────────────────────────────────────────────────────────
// 3. generateDashboard — AI dashboard generation from natural language
// ──────────────────────────────────────────────────────────────
exports.generateDashboard = onDocumentCreated(
  `${USERS}/{uid}/${AI_JOBS}/{jobId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const job = snap.data();
    if (job.type !== 'dashboard_generation') return;

    const { uid, jobId } = event.params;

    try {
      await snap.ref.update({ status: 'processing', progress: 0.2 });

      const vid = job.vehicleId;
      const vehicleSnap = await db.doc(paths.vehicle(uid, vid)).get();
      const vehicle = vehicleSnap.data() || {};

      await snap.ref.update({ progress: 0.5 });

      const dashboard = await callGeminiPro(
        buildDashboardPrompt(vehicle, job.params?.prompt || 'general monitoring'),
        'medium'
      );

      // Write dashboard to dashboards subcollection
      const dashRef = db.collection(paths.dashboards(uid)).doc();
      await dashRef.set({
        ...dashboard,
        vehicleId: vid,
        createdAt: FieldValue.serverTimestamp(),
        source: 'ai_generated',
        aiJobId: jobId,
      });

      await snap.ref.update({
        status: 'completed',
        progress: 1.0,
        result: { dashboardId: dashRef.id, ...dashboard },
        completedAt: FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`generateDashboard failed for ${jobId}:`, err);
      await snap.ref.update({
        status: 'error',
        error: err.message,
        completedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

// ──────────────────────────────────────────────────────────────
// 4. checkPredictiveMaintenance — daily scheduled (3:00 AM UTC)
// ──────────────────────────────────────────────────────────────
exports.checkPredictiveMaintenance = onSchedule(
  { schedule: '0 3 * * *', timeZone: 'UTC' },
  async () => {
    try {
      // Iterate all users → vehicles
      const usersSnap = await db.collection(USERS).get();

      for (const userDoc of usersSnap.docs) {
        const uid = userDoc.id;
        const vehiclesSnap = await db
          .collection(`${USERS}/${uid}/${VEHICLES}`)
          .get();

        for (const vehicleDoc of vehiclesSnap.docs) {
          const vid = vehicleDoc.id;
          const vehicle = vehicleDoc.data();

          // Get recent drives
          const drivesSnap = await db
            .collection(paths.vehicle(uid, vid) + `/${DRIVES}`)
            .orderBy('startTime', 'desc')
            .limit(30)
            .get();
          if (drivesSnap.empty) continue;
          const drives = drivesSnap.docs.map(d => ({ id: d.id, ...d.data() }));

          // Get maintenance history
          const maintSnap = await db
            .collection(paths.maintenance(uid, vid))
            .orderBy('date', 'desc')
            .get();
          const maintenance = maintSnap.docs.map(d => d.data());

          // Run prediction
          const result = await callGeminiPro(
            buildMaintenancePredictionPrompt(vehicle, drives, maintenance),
            'high'
          );

          // Write predictions as maintenance records with type='predicted'
          if (result.predictions) {
            for (const pred of result.predictions) {
              await db.collection(paths.maintenance(uid, vid)).add({
                type: pred.type,
                source: 'ai_prediction',
                urgency: pred.urgency,
                estimatedDate: pred.estimatedDate,
                estimatedMiles: pred.estimatedMiles || null,
                confidence: pred.confidence,
                reasoning: pred.reasoning,
                status: 'predicted',
                createdAt: FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
    } catch (err) {
      console.error('checkPredictiveMaintenance failed:', err);
    }
  }
);

// ──────────────────────────────────────────────────────────────
// 5. computeBaseline — weekly scheduled (Sunday 4:00 AM UTC)
// ──────────────────────────────────────────────────────────────
exports.computeBaseline = onSchedule(
  { schedule: '0 4 * * 0', timeZone: 'UTC' },
  async () => {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const usersSnap = await db.collection(USERS).get();

      for (const userDoc of usersSnap.docs) {
        const uid = userDoc.id;
        const vehiclesSnap = await db
          .collection(`${USERS}/${uid}/${VEHICLES}`)
          .get();

        for (const vehicleDoc of vehiclesSnap.docs) {
          const vid = vehicleDoc.id;
          const vehicle = vehicleDoc.data();

          const drivesSnap = await db
            .collection(paths.vehicle(uid, vid) + `/${DRIVES}`)
            .where('startTime', '>=', thirtyDaysAgo.toISOString())
            .orderBy('startTime')
            .get();
          if (drivesSnap.empty) continue;
          const drives = drivesSnap.docs.map(d => ({ id: d.id, ...d.data() }));

          const baselines = await callGeminiFlash(
            buildBaselinePrompt(vehicle, drives),
            2048
          );

          // Write baselines to vehicle doc
          await vehicleDoc.ref.update({
            baselineData: baselines,
            baselineUpdatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (err) {
      console.error('computeBaseline failed:', err);
    }
  }
);

// ──────────────────────────────────────────────────────────────
// 6. processVehicleShare — handle sharing invitations
// ──────────────────────────────────────────────────────────────
exports.processVehicleShare = onDocumentCreated(
  `${USERS}/{uid}/${VEHICLES}/{vid}/${SHARING}/{shareId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const share = snap.data();
    const { uid, vid, shareId } = event.params;

    try {
      // Create a global invite document for lookup by invite code
      const inviteCode = share.inviteCode || shareId;
      await db.collection('invites').doc(inviteCode).set({
        ownerUid: uid,
        vehicleId: vid,
        shareId,
        inviteeEmail: share.email || null,
        permissions: share.permissions || ['read'],
        createdAt: FieldValue.serverTimestamp(),
        status: 'pending',
      });

      // If we know the invitee's email, try to find their UID and set up access
      if (share.email) {
        const inviteeSnap = await db
          .collection(USERS)
          .where('email', '==', share.email)
          .limit(1)
          .get();

        if (!inviteeSnap.empty) {
          const inviteeUid = inviteeSnap.docs[0].id;
          // Add shared vehicle reference to invitee's account
          await db
            .collection(`${USERS}/${inviteeUid}/sharedVehicles`)
            .doc(`${uid}_${vid}`)
            .set({
              ownerUid: uid,
              vehicleId: vid,
              permissions: share.permissions || ['read'],
              acceptedAt: FieldValue.serverTimestamp(),
            });

          await db.collection('invites').doc(inviteCode).update({
            status: 'accepted',
            inviteeUid,
          });
        }
      }

      await snap.ref.update({ processed: true });
    } catch (err) {
      console.error(`processVehicleShare failed for ${shareId}:`, err);
      await snap.ref.update({ error: err.message });
    }
  }
);

// ──────────────────────────────────────────────────────────────
// 7. decodeVin — NHTSA VIN decoder on vehicle creation
// ──────────────────────────────────────────────────────────────
exports.decodeVin = onDocumentCreated(
  `${USERS}/{uid}/${VEHICLES}/{vid}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const vehicle = snap.data();
    const vin = vehicle.vin;
    if (!vin) return;

    try {
      const resp = await fetch(
        `https://vpic.nhtsa.dot.gov/api/vehicles/decodevin/${vin}?format=json`
      );
      const data = await resp.json();

      const results = data.Results || [];
      const decoded = {};
      for (const item of results) {
        if (item.Value && item.Value.trim()) {
          decoded[item.Variable] = item.Value.trim();
        }
      }

      await snap.ref.update({
        vinDecoded: {
          make: decoded['Make'] || null,
          model: decoded['Model'] || null,
          year: decoded['Model Year'] || null,
          engineDisplacement: decoded['Displacement (L)'] || null,
          engineCylinders: decoded['Engine Number of Cylinders'] || null,
          fuelType: decoded['Fuel Type - Primary'] || null,
          driveType: decoded['Drive Type'] || null,
          bodyClass: decoded['Body Class'] || null,
          gvwr: decoded['Gross Vehicle Weight Rating From'] || null,
          transmissionStyle: decoded['Transmission Style'] || null,
          plant: decoded['Plant City'] || null,
        },
        vinDecodedAt: FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`decodeVin failed for VIN ${vin}:`, err);
      await snap.ref.update({ vinError: err.message });
    }
  }
);

// ──────────────────────────────────────────────────────────────
// 8. exportDriveData — export drive data as CSV/JSON
// ──────────────────────────────────────────────────────────────
exports.exportDriveData = onDocumentCreated(
  `${USERS}/{uid}/${AI_JOBS}/{jobId}`,
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const job = snap.data();
    if (job.type !== 'export') return;

    const { uid, jobId } = event.params;

    try {
      await snap.ref.update({ status: 'processing', progress: 0.1 });

      const vid = job.vehicleId;
      const driveIds = job.params?.driveIds || [];
      const format = job.params?.format || 'csv';
      const allRows = [];

      await snap.ref.update({ progress: 0.3 });

      for (const did of driveIds) {
        // Check if drive has timeseries in Storage
        const driveDoc = await db.doc(paths.drive(uid, vid, did)).get();
        const driveData = driveDoc.data() || {};

        if (driveData.timeseriesPath && driveData.timeseriesUploaded) {
          // New path: read from Firebase Storage
          const rows = await readTimeseries(driveData.timeseriesPath);
          for (const row of rows) {
            allRows.push({ driveId: did, ...row });
          }
        } else {
          // Legacy fallback: read from Firestore subcollection
          const datapointsSnap = await db
            .collection(paths.datapoints(uid, vid, did))
            .orderBy('timestamp')
            .get();

          for (const dp of datapointsSnap.docs) {
            allRows.push({ driveId: did, ...dp.data() });
          }
        }
      }

      await snap.ref.update({ progress: 0.6 });

      let content;
      let contentType;
      let ext;

      if (format === 'json') {
        content = JSON.stringify(allRows, null, 2);
        contentType = 'application/json';
        ext = 'json';
      } else {
        // CSV format
        if (allRows.length === 0) {
          content = '';
        } else {
          const headers = Object.keys(allRows[0]);
          const csvRows = [headers.join(',')];
          for (const row of allRows) {
            csvRows.push(headers.map(h => {
              const val = row[h];
              if (val === null || val === undefined) return '';
              const str = String(val);
              return str.includes(',') ? `"${str}"` : str;
            }).join(','));
          }
          content = csvRows.join('\n');
        }
        contentType = 'text/csv';
        ext = 'csv';
      }

      await snap.ref.update({ progress: 0.8 });

      // Upload to Cloud Storage
      const bucket = getStorage().bucket();
      const filePath = `exports/${uid}/${vid}/${jobId}.${ext}`;
      const file = bucket.file(filePath);

      await file.save(content, { contentType });

      // Generate signed download URL (valid 7 days)
      const [downloadUrl] = await file.getSignedUrl({
        action: 'read',
        expires: Date.now() + 7 * 24 * 60 * 60 * 1000,
      });

      await snap.ref.update({
        status: 'completed',
        progress: 1.0,
        result: {
          downloadUrl,
          filePath,
          rowCount: allRows.length,
          format,
        },
        completedAt: FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`exportDriveData failed for ${jobId}:`, err);
      await snap.ref.update({
        status: 'error',
        error: err.message,
        completedAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

// ──────────────────────────────────────────────────────────────
// Helper: Build stats object from drive doc's parameterStats map
// ──────────────────────────────────────────────────────────────
function aggregateDriveStats(drive, parameterStats) {
  const stats = {
    datapointCount: drive.datapointCount || 0,
    durationSeconds: drive.durationSeconds || 0,
    distanceMiles: drive.distanceMiles || 0,
    sensorList: drive.sensorList || [],
  };

  // parameterStats is already { key: { min, max, avg, count }, ... }
  if (parameterStats && typeof parameterStats === 'object') {
    for (const [key, agg] of Object.entries(parameterStats)) {
      if (agg && typeof agg === 'object') {
        if (agg.avg != null) stats[`avg_${key}`] = agg.avg;
        if (agg.min != null) stats[`min_${key}`] = agg.min;
        if (agg.max != null) stats[`max_${key}`] = agg.max;
        if (agg.count != null) stats[`count_${key}`] = agg.count;
      }
    }
  }

  return stats;
}
