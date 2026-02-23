'use strict';

// Collection name constants
const USERS = 'users';
const VEHICLES = 'vehicles';
const DRIVES = 'drives';
const DATAPOINTS = 'datapoints';
const MAINTENANCE = 'maintenance';
const AI_JOBS = 'aiJobs';
const SHARING = 'sharing';

// Path builders
const paths = {
  user: (uid) => `${USERS}/${uid}`,
  vehicle: (uid, vid) => `${USERS}/${uid}/${VEHICLES}/${vid}`,
  drives: (uid, vid) => `${USERS}/${uid}/${VEHICLES}/${vid}/${DRIVES}`,
  drive: (uid, vid, did) =>
    `${USERS}/${uid}/${VEHICLES}/${vid}/${DRIVES}/${did}`,
  datapoints: (uid, vid, did) =>
    `${USERS}/${uid}/${VEHICLES}/${vid}/${DRIVES}/${did}/${DATAPOINTS}`,
  maintenance: (uid, vid) =>
    `${USERS}/${uid}/${VEHICLES}/${vid}/${MAINTENANCE}`,
  dashboards: (uid) => `${USERS}/${uid}/dashboards`,
  aiJobs: (uid) => `${USERS}/${uid}/${AI_JOBS}`,
};

module.exports = {
  paths,
  USERS,
  VEHICLES,
  DRIVES,
  DATAPOINTS,
  MAINTENANCE,
  AI_JOBS,
  SHARING,
};
