import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance_record.dart';
import '../models/service_schedule.dart';
import '../models/checklist_session.dart';
import '../models/seasonal_task.dart';
import '../config/constants.dart';
import '../config/maintenance_templates.dart';
import 'vehicle_provider.dart';

// ─── Helpers ───

CollectionReference? _subcollection(String? uid, String? vehicleId, String sub) {
  if (uid == null || vehicleId == null) return null;
  return FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.vehiclesSubcollection)
      .doc(vehicleId)
      .collection(sub);
}

// ─── Existing: Maintenance Records Stream ───

final maintenanceStreamProvider =
    StreamProvider<List<MaintenanceRecord>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return _subcollection(uid, vehicle.id, AppConstants.maintenanceSubcollection)!
      .orderBy('date', descending: true)
      .snapshots()
      .map((snap) =>
          snap.docs.map(MaintenanceRecord.fromFirestore).toList());
});

// ─── New: Service Schedules Stream ───

final serviceSchedulesProvider =
    StreamProvider<List<ServiceSchedule>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return _subcollection(uid, vehicle.id, AppConstants.serviceSchedulesSubcollection)!
      .orderBy('sortOrder')
      .snapshots()
      .map((snap) =>
          snap.docs.map(ServiceSchedule.fromFirestore).toList());
});

// ─── New: Checklist Sessions Stream (recent 10) ───

final checklistSessionsProvider =
    StreamProvider<List<ChecklistSession>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return _subcollection(uid, vehicle.id, AppConstants.checklistSessionsSubcollection)!
      .orderBy('startedAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snap) =>
          snap.docs.map(ChecklistSession.fromFirestore).toList());
});

// ─── New: Seasonal Tasks Stream (current year) ───

final seasonalTasksProvider =
    StreamProvider<List<SeasonalTask>>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  if (uid == null || vehicle == null) return const Stream.empty();

  return _subcollection(uid, vehicle.id, AppConstants.seasonalTasksSubcollection)!
      .where('year', isEqualTo: DateTime.now().year)
      .snapshots()
      .map((snap) =>
          snap.docs.map(SeasonalTask.fromFirestore).toList());
});

// ─── Urgency Provider ───

class MaintenanceUrgency {
  final int overdueCount;
  final int dueSoonCount;
  final double ytdCost;

  const MaintenanceUrgency({
    this.overdueCount = 0,
    this.dueSoonCount = 0,
    this.ytdCost = 0,
  });
}

final maintenanceUrgencyProvider = Provider<MaintenanceUrgency>((ref) {
  final schedulesAsync = ref.watch(serviceSchedulesProvider);
  final recordsAsync = ref.watch(maintenanceStreamProvider);
  final vehicle = ref.watch(activeVehicleProvider);

  final schedules = schedulesAsync.value ?? [];
  final records = recordsAsync.value ?? [];
  final odometer = vehicle?.currentOdometer ?? 0;
  // Engine hours from vehicle doc (0 if not yet tracked — hours-based
  // triggers will be inactive until OBD data populates this field).
  final hours = vehicle?.currentEngineHours ?? 0;

  int overdue = 0;
  int dueSoon = 0;
  for (final s in schedules) {
    if (!s.isEnabled) continue;
    if (s.isOverdue(odometer, currentHours: hours)) {
      overdue++;
    } else if (s.isDueSoon(odometer, currentHours: hours)) {
      dueSoon++;
    }
  }

  final now = DateTime.now();
  final ytdStart = DateTime(now.year, 1, 1);
  double ytdCost = 0;
  for (final r in records) {
    if (r.date.isAfter(ytdStart) && r.cost != null) {
      ytdCost += r.cost!;
    }
  }

  return MaintenanceUrgency(
    overdueCount: overdue,
    dueSoonCount: dueSoon,
    ytdCost: ytdCost,
  );
});

// ─── Tab State ───

enum MaintenanceTab { dashboard, schedule, checklists, seasonal, history }

class MaintenanceTabNotifier extends Notifier<MaintenanceTab> {
  @override
  MaintenanceTab build() => MaintenanceTab.dashboard;

  void set(MaintenanceTab tab) => state = tab;
}

final maintenanceTabProvider =
    NotifierProvider<MaintenanceTabNotifier, MaintenanceTab>(
        MaintenanceTabNotifier.new);

// ─── Repository ───

final maintenanceRepositoryProvider =
    Provider<MaintenanceRepository>((ref) {
  final uid = ref.watch(userIdProvider);
  final vehicle = ref.watch(activeVehicleProvider);
  return MaintenanceRepository(uid: uid, vehicleId: vehicle?.id);
});

class MaintenanceRepository {
  final String? uid;
  final String? vehicleId;
  final _db = FirebaseFirestore.instance;

  MaintenanceRepository({this.uid, this.vehicleId});

  CollectionReference? _maintenanceRef() =>
      _subcollection(uid, vehicleId, AppConstants.maintenanceSubcollection);

  CollectionReference? _schedulesRef() =>
      _subcollection(uid, vehicleId, AppConstants.serviceSchedulesSubcollection);

  CollectionReference? _checklistsRef() =>
      _subcollection(uid, vehicleId, AppConstants.checklistSessionsSubcollection);

  CollectionReference? _seasonalRef() =>
      _subcollection(uid, vehicleId, AppConstants.seasonalTasksSubcollection);

  // ── Maintenance Records CRUD ──

  Future<String?> add(MaintenanceRecord record) async {
    final ref = _maintenanceRef();
    if (ref == null) return null;
    final doc = await ref.add(record.toFirestore());
    return doc.id;
  }

  Future<void> update(MaintenanceRecord record) async {
    await _maintenanceRef()?.doc(record.id).update(record.toFirestore());
  }

  Future<void> delete(String recordId) async {
    await _maintenanceRef()?.doc(recordId).delete();
  }

  Future<void> markComplete(String recordId) async {
    await _maintenanceRef()?.doc(recordId).update({'isCompleted': true});
  }

  // ── Service Schedules Bootstrap ──

  Future<void> initializeSchedules() async {
    final ref = _schedulesRef();
    if (ref == null) return;

    final snap = await ref.limit(1).get();
    if (snap.docs.isNotEmpty) {
      // Already initialized — seed baseline for any docs missing lastServiceMiles
      await _seedBaselineIfNeeded(ref);
      return;
    }

    // First-time bootstrap: create all schedules with baseline "new truck" values
    final now = DateTime.now();
    final batch = _db.batch();
    for (int i = 0; i < kServiceTypes.length; i++) {
      final t = kServiceTypes[i];
      final doc = ref.doc(t.id);
      batch.set(doc, ServiceSchedule(
        id: t.id,
        vehicleId: vehicleId!,
        serviceTypeId: t.id,
        name: t.name,
        intervalMiles: t.defaultIntervalMiles,
        intervalMonths: t.defaultIntervalMonths,
        intervalHours: t.defaultIntervalHours,
        lastServiceMiles: 0,
        lastServiceDate: now,
        lastServiceHours: t.defaultIntervalHours != null ? 0 : null,
        isEnabled: true,
        sortOrder: i,
      ).toFirestore());
    }
    await batch.commit();
  }

  /// Backfill baseline values for schedule docs that were created without them.
  Future<void> _seedBaselineIfNeeded(CollectionReference ref) async {
    final snap = await ref.where('lastServiceMiles', isNull: true).get();
    if (snap.docs.isEmpty) return;

    final now = DateTime.now();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      final hasHours = d['intervalHours'] != null;
      batch.update(doc.reference, {
        'lastServiceMiles': 0,
        'lastServiceDate': Timestamp.fromDate(now),
        if (hasHours) 'lastServiceHours': 0,
      });
    }
    await batch.commit();
  }

  // ── Log Service & Update Schedule ──

  Future<String?> logServiceAndUpdateSchedule({
    required MaintenanceRecord record,
    String? serviceTypeId,
    double? odometerReading,
    double? engineHours,
  }) async {
    final recordId = await add(record);
    if (recordId == null) return null;

    if (serviceTypeId != null) {
      final schedRef = _schedulesRef()?.doc(serviceTypeId);
      if (schedRef != null) {
        final updateData = <String, dynamic>{
          'lastServiceMiles': odometerReading,
          'lastServiceDate': Timestamp.fromDate(record.date),
          'lastServiceRecordId': recordId,
        };
        if (engineHours != null) {
          updateData['lastServiceHours'] = engineHours;
        }
        await schedRef.update(updateData);
      }
    }

    return recordId;
  }

  // ── Checklists ──

  Future<String?> startChecklist({
    required String checklistTypeId,
    required List<String> itemIds,
    double? odometerReading,
  }) async {
    final ref = _checklistsRef();
    if (ref == null) return null;

    final session = ChecklistSession(
      id: '',
      vehicleId: vehicleId!,
      checklistTypeId: checklistTypeId,
      startedAt: DateTime.now(),
      odometerReading: odometerReading,
      itemStates: {for (final id in itemIds) id: false},
    );

    final doc = await ref.add(session.toFirestore());
    return doc.id;
  }

  Future<void> updateChecklistItem(String sessionId, String itemId, bool value) async {
    await _checklistsRef()?.doc(sessionId).update({
      'itemStates.$itemId': value,
    });
  }

  Future<void> completeChecklist(String sessionId) async {
    await _checklistsRef()?.doc(sessionId).update({
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Seasonal Tasks ──

  Future<void> markSeasonalTaskDone({
    required String seasonalGroupId,
    required String taskId,
    required String season,
    String? notes,
  }) async {
    final ref = _seasonalRef();
    if (ref == null) return;

    final compositeId = '${DateTime.now().year}_${seasonalGroupId}_$taskId';
    await ref.doc(compositeId).set(SeasonalTask(
      id: compositeId,
      vehicleId: vehicleId!,
      seasonalGroupId: seasonalGroupId,
      taskId: taskId,
      year: DateTime.now().year,
      season: season,
      completedAt: DateTime.now(),
      notes: notes,
    ).toFirestore());
  }

  Future<void> unmarkSeasonalTask({
    required String seasonalGroupId,
    required String taskId,
  }) async {
    final ref = _seasonalRef();
    if (ref == null) return;
    final compositeId = '${DateTime.now().year}_${seasonalGroupId}_$taskId';
    await ref.doc(compositeId).delete();
  }
}
