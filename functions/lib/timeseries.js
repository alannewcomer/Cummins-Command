'use strict';

const { getStorage } = require('firebase-admin/storage');
const zlib = require('zlib');
const { promisify } = require('util');

const gunzip = promisify(zlib.gunzip);

/**
 * Read a column-oriented gzip'd JSON timeseries file from Firebase Storage.
 * Returns an array of row objects (one per timestamp).
 *
 * @param {string} storagePath  Cloud Storage path, e.g.
 *   "drives/{uid}/{vid}/{did}/timeseries.json.gz"
 * @returns {Promise<Array<Object>>} rows with timestamp + sensor fields
 */
async function readTimeseries(storagePath) {
  const bucket = getStorage().bucket();
  const file = bucket.file(storagePath);

  const [compressed] = await file.download();
  const json = await gunzip(compressed);
  const payload = JSON.parse(json.toString('utf8'));

  const count = payload.count || 0;
  const columns = payload.columns || {};
  const timestamps = columns.timestamp || [];

  const rows = [];
  for (let i = 0; i < count; i++) {
    const row = { timestamp: timestamps[i] };
    for (const [key, col] of Object.entries(columns)) {
      if (key === 'timestamp') continue;
      if (Array.isArray(col) && i < col.length && col[i] != null) {
        row[key] = col[i];
      }
    }
    rows.push(row);
  }

  return rows;
}

/**
 * Read the raw column-oriented payload (not expanded to rows).
 * More memory-efficient for Parquet conversion since we can write
 * columns directly.
 *
 * @param {string} storagePath
 * @returns {Promise<{count: number, columns: Object}>}
 */
async function readTimeseriesColumns(storagePath) {
  const bucket = getStorage().bucket();
  const file = bucket.file(storagePath);

  const [compressed] = await file.download();
  const json = await gunzip(compressed);
  const payload = JSON.parse(json.toString('utf8'));

  return {
    count: payload.count || 0,
    columns: payload.columns || {},
  };
}

module.exports = { readTimeseries, readTimeseriesColumns };
