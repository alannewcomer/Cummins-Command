class AppConstants {
  AppConstants._();

  // App info
  static const appName = 'Cummins Command';
  static const appVersion = '2.0.0';

  // Bluetooth / OBD
  static const obdDeviceName = 'OBDLink MX+';
  static const obdBaudRate = 115200;
  static const obdTimeout = Duration(seconds: 2);
  static const btScanTimeout = Duration(seconds: 15);
  static const btReconnectDelay = Duration(seconds: 3);
  static const btMaxReconnectAttempts = 10;
  static const btReconnectBackoffMultiplier = 1.5;

  // AT command init sequence for OBDLink MX+
  static const atInitCommands = [
    'ATZ',     // Reset
    'ATE0',    // Echo off
    'ATL0',    // Linefeeds off
    'ATS0',    // Spaces off
    'ATH1',    // Headers on (needed for J1939)
    'ATSP0',   // Auto protocol detect
    'ATAT1',   // Adaptive timing on
    'ATST64',  // Timeout 100ms (64 hex = 100)
  ];

  // Polling intervals (milliseconds)
  static const pollFast = 500;
  static const pollMedium = 1000;
  static const pollSlow = 2000;
  static const pollBackground = 5000;

  // Drive detection
  static const driveStartSpeedThreshold = 5.0; // mph
  static const driveEndIdleMinutes = 5;
  static const firestoreBatchInterval = Duration(seconds: 5);

  // Engine state detection
  static const engineOffRpmThreshold = 50.0;       // RPM below this = engine off (allow noise)
  static const engineOffConfirmSeconds = 10;        // Seconds of RPM=0 before accessory state
  static const accessoryVoltageThreshold = 12.4;    // Below this = key off (resting battery ~12.6V, under load ~12.2V)
  static const accessoryToOffSeconds = 30;          // Seconds of low voltage before off state (fallback path)
  static const accessoryPollIntervalMs = 2000;      // Poll interval in accessory mode

  // Alternator-off detection — fast engine-off path
  // When alternator was charging (>13.5V) and voltage drops below 13.0V,
  // the engine is definitely off. Confirm in 10s (not 120s).
  static const alternatorChargingVoltage = 13.5;    // Above this = alternator running
  static const alternatorOffVoltage = 13.0;         // Below this after charging = alternator stopped
  static const alternatorOffConfirmSeconds = 10;    // Quick confirm after voltage drop

  // Sleep reconnect — three-phase strategy after engine-off sleep disconnect.
  //
  // Phase A (0-5 min):  30s polling — covers quick restarts (gas station)
  // Phase B (5-35 min): QUIET — let MX+ BatterySaver fully power down BT radio
  // Phase C (35+ min):  60s polling — MX+ BT is OFF, attempts instant-fail, harmless
  //
  // Loop detection: if two sleep disconnects happen within 5 min, it means
  // we reconnected during Phase A and immediately detected engine-off again.
  // Skip straight to Phase B to avoid keeping the MX+ awake.
  static const sleepReconnectPhaseAInterval = Duration(seconds: 30);
  static const sleepReconnectPhaseADuration = Duration(minutes: 5);
  static const sleepReconnectPhaseBDuration = Duration(minutes: 30);
  static const sleepReconnectPhaseCInterval = Duration(seconds: 60);

  // SharedPreferences keys
  static const savedAdapterAddressKey = 'last_obd_adapter_address';
  static const devLogsCloudEnabledKey = 'dev_logs_cloud_enabled';

  // Firestore paths
  static const usersCollection = 'users';
  static const vehiclesSubcollection = 'vehicles';
  static const drivesSubcollection = 'drives';
  static const datapointsSubcollection = 'datapoints';
  static const dashboardsSubcollection = 'dashboards';
  static const maintenanceSubcollection = 'maintenance';
  static const serviceSchedulesSubcollection = 'serviceSchedules';
  static const checklistSessionsSubcollection = 'checklistSessions';
  static const seasonalTasksSubcollection = 'seasonalTasks';
  static const sharingSubcollection = 'sharing';
  static const aiJobsSubcollection = 'aiJobs';
  static const routesSubcollection = 'routes';
  static const dashboardTemplatesCollection = 'dashboardTemplates';
  static const pidDefinitionsCollection = 'pidDefinitions';

  // AI
  static const geminiProModel = 'gemini-3.1-pro-preview';
  static const geminiFlashModel = 'gemini-2.5-flash';
  static const geminiExplorerFlashModel = 'gemini-3-flash-preview';
  static const aiStatusStripRefreshInterval = Duration(seconds: 10);
  static const maxChatHistory = 50;

  // Data Explorer
  static const maxOverlayParams = 6;
  static const maxDatapointsRender = 100000;

  // Firebase Storage
  static const timeseriesStoragePrefix = 'drives';

  // Maintenance
  static const maintenanceCategories = [
    'Oil Change',
    'Oil Filter',
    'Fuel Filter',
    'Air Filter',
    'DEF Fluid',
    'Transmission Service',
    'Coolant Flush',
    'DPF Cleaning',
    'Turbo Inspection',
    'Brake Service',
    'Tire Rotation',
    'Battery',
    'Belt Replacement',
    'Exhaust Inspection',
    'Other',
  ];
}
