'use strict';

const parquet = require('@dsnp/parquetjs');
const os = require('os');
const path = require('path');
const fs = require('fs');
const { getStorage } = require('firebase-admin/storage');

/**
 * Parquet schema for Cummins Command time-series data.
 *
 * Every sensor column is an optional DOUBLE. The schema matches the
 * _columnFields list in the Flutter TimeseriesWriter so that any column
 * present in the gzip'd JSON maps 1:1 to a Parquet column.
 *
 * Metadata columns (driveId, vehicleId, userId) are embedded in each row
 * so that BigQuery external tables can query across all drives without
 * needing hive-style partitioning.
 */
const PARQUET_SCHEMA = new parquet.ParquetSchema({
  // ─── Metadata (embedded for cross-drive queries) ───
  userId:    { type: 'UTF8', optional: true },
  vehicleId: { type: 'UTF8', optional: true },
  driveId:   { type: 'UTF8', optional: true },

  // ─── Timestamp ───
  timestamp: { type: 'INT64' },

  // ─── OBD2 / J1939 Sensor Parameters ───
  rpm:                   { type: 'DOUBLE', optional: true },
  speed:                 { type: 'DOUBLE', optional: true },
  coolantTemp:           { type: 'DOUBLE', optional: true },
  intakeTemp:            { type: 'DOUBLE', optional: true },
  maf:                   { type: 'DOUBLE', optional: true },
  throttlePos:           { type: 'DOUBLE', optional: true },
  boostPressure:         { type: 'DOUBLE', optional: true },
  egt:                   { type: 'DOUBLE', optional: true },
  egt2:                  { type: 'DOUBLE', optional: true },
  egt3:                  { type: 'DOUBLE', optional: true },
  egt4:                  { type: 'DOUBLE', optional: true },
  transTemp:             { type: 'DOUBLE', optional: true },
  oilTemp:               { type: 'DOUBLE', optional: true },
  oilPressure:           { type: 'DOUBLE', optional: true },
  engineLoad:            { type: 'DOUBLE', optional: true },
  turboSpeed:            { type: 'DOUBLE', optional: true },
  vgtPosition:           { type: 'DOUBLE', optional: true },
  egrPosition:           { type: 'DOUBLE', optional: true },
  dpfSootLoad:           { type: 'DOUBLE', optional: true },
  dpfRegenStatus:        { type: 'DOUBLE', optional: true },
  dpfDiffPressure:       { type: 'DOUBLE', optional: true },
  noxPreScr:             { type: 'DOUBLE', optional: true },
  noxPostScr:            { type: 'DOUBLE', optional: true },
  defLevel:              { type: 'DOUBLE', optional: true },
  defTemp:               { type: 'DOUBLE', optional: true },
  defDosingRate:         { type: 'DOUBLE', optional: true },
  defQuality:            { type: 'DOUBLE', optional: true },
  railPressure:          { type: 'DOUBLE', optional: true },
  crankcasePressure:     { type: 'DOUBLE', optional: true },
  coolantLevel:          { type: 'DOUBLE', optional: true },
  intercoolerOutletTemp: { type: 'DOUBLE', optional: true },
  exhaustBackpressure:   { type: 'DOUBLE', optional: true },
  fuelRate:              { type: 'DOUBLE', optional: true },
  fuelLevel:             { type: 'DOUBLE', optional: true },
  batteryVoltage:        { type: 'DOUBLE', optional: true },
  ambientTemp:           { type: 'DOUBLE', optional: true },
  barometric:            { type: 'DOUBLE', optional: true },
  odometer:              { type: 'DOUBLE', optional: true },
  engineHours:           { type: 'DOUBLE', optional: true },
  gearRatio:             { type: 'DOUBLE', optional: true },

  // ─── Diesel-Specific OBD2 ───
  accelPedalD:           { type: 'DOUBLE', optional: true },
  demandTorque:          { type: 'DOUBLE', optional: true },
  actualTorque:          { type: 'DOUBLE', optional: true },
  referenceTorque:       { type: 'DOUBLE', optional: true },
  commandedEgr:          { type: 'DOUBLE', optional: true },
  commandedThrottle:     { type: 'DOUBLE', optional: true },
  boostPressureCtrl:     { type: 'DOUBLE', optional: true },
  vgtControlObd:         { type: 'DOUBLE', optional: true },
  turboInletPressure:    { type: 'DOUBLE', optional: true },
  turboInletTemp:        { type: 'DOUBLE', optional: true },
  chargeAirTemp:         { type: 'DOUBLE', optional: true },
  egtObd2:               { type: 'DOUBLE', optional: true },
  dpfTemp:               { type: 'DOUBLE', optional: true },
  runtimeExtended:       { type: 'DOUBLE', optional: true },

  // ─── GPS ───
  lat:       { type: 'DOUBLE', optional: true },
  lng:       { type: 'DOUBLE', optional: true },
  altitude:  { type: 'DOUBLE', optional: true },
  gpsSpeed:  { type: 'DOUBLE', optional: true },
  heading:   { type: 'DOUBLE', optional: true },

  // ─── Calculated ───
  instantMPG:      { type: 'DOUBLE', optional: true },
  estimatedGear:   { type: 'DOUBLE', optional: true },
  estimatedHP:     { type: 'DOUBLE', optional: true },
  estimatedTorque: { type: 'DOUBLE', optional: true },
});

/**
 * Convert column-oriented timeseries data to a Parquet file and upload
 * to Cloud Storage.
 *
 * @param {Object} opts
 * @param {number} opts.count          Number of rows
 * @param {Object} opts.columns        Column-oriented data {name: [values]}
 * @param {string} opts.userId
 * @param {string} opts.vehicleId
 * @param {string} opts.driveId
 * @returns {Promise<string>} GCS path of the uploaded Parquet file
 */
async function convertToParquet({ count, columns, userId, vehicleId, driveId }) {
  const tmpFile = path.join(os.tmpdir(), `${driveId}.parquet`);

  try {
    const writer = await parquet.ParquetWriter.openFile(PARQUET_SCHEMA, tmpFile, {
      compression: 'SNAPPY',
      rowGroupSize: 10000,
    });

    const timestamps = columns.timestamp || [];
    const sensorKeys = Object.keys(columns).filter(k => k !== 'timestamp');

    for (let i = 0; i < count; i++) {
      const row = {
        userId,
        vehicleId,
        driveId,
        timestamp: BigInt(timestamps[i] || 0),
      };

      for (const key of sensorKeys) {
        const col = columns[key];
        if (Array.isArray(col) && i < col.length && col[i] != null) {
          row[key] = col[i];
        }
      }

      await writer.appendRow(row);
    }

    await writer.close();

    // Upload to GCS
    const bucket = getStorage().bucket();
    const gcsPath = `parquet/${userId}/${vehicleId}/${driveId}.parquet`;

    await bucket.upload(tmpFile, {
      destination: gcsPath,
      metadata: {
        contentType: 'application/octet-stream',
        metadata: {
          driveId,
          vehicleId,
          userId,
          format: 'parquet',
          schema_version: '1',
        },
      },
    });

    console.log(`Parquet uploaded: ${gcsPath} (${count} rows)`);
    return gcsPath;
  } finally {
    // Clean up temp file
    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }
  }
}

module.exports = { convertToParquet, PARQUET_SCHEMA };
