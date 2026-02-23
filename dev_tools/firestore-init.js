// Shared Firestore initialization for dev tools.
// Uses firebase-admin with Application Default Credentials (works in Firebase Studio).

const path = require('path');
const admin = require(path.resolve(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'cummins-comand' });
}

const db = admin.firestore();

module.exports = { admin, db };
