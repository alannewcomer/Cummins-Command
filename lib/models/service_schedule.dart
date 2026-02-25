import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which trigger is closest to (or past) its limit.
enum UrgencyTrigger { miles, time, hours, none }

/// A configured recurring service interval for a vehicle.
/// Tracks three independent triggers — whichever comes first wins.
/// One doc per service type in `/users/{uid}/vehicles/{vid}/serviceSchedules/{id}`.
class ServiceSchedule {
  final String id;
  final String vehicleId;
  final String serviceTypeId;
  final String name;

  // Interval thresholds (all "whichever comes first")
  final int intervalMiles;
  final int? intervalMonths;
  final int? intervalHours; // engine hours

  // Last service snapshot
  final double? lastServiceMiles;
  final DateTime? lastServiceDate;
  final double? lastServiceHours; // engine hours at last service
  final String? lastServiceRecordId;

  final bool isEnabled;
  final int sortOrder;

  const ServiceSchedule({
    required this.id,
    required this.vehicleId,
    required this.serviceTypeId,
    required this.name,
    required this.intervalMiles,
    this.intervalMonths,
    this.intervalHours,
    this.lastServiceMiles,
    this.lastServiceDate,
    this.lastServiceHours,
    this.lastServiceRecordId,
    this.isEnabled = true,
    this.sortOrder = 0,
  });

  // ─── Next-Due Calculations ───

  double? nextDueMiles(double currentOdometer) {
    if (lastServiceMiles == null) return null;
    return lastServiceMiles! + intervalMiles;
  }

  DateTime? get nextDueDate {
    if (lastServiceDate == null || intervalMonths == null) return null;
    return DateTime(
      lastServiceDate!.year,
      lastServiceDate!.month + intervalMonths!,
      lastServiceDate!.day,
    );
  }

  double? get nextDueHours {
    if (lastServiceHours == null || intervalHours == null) return null;
    return lastServiceHours! + intervalHours!;
  }

  // ─── Per-Trigger Progress (0.0 = fresh, 1.0 = due, >1.0 = overdue) ───

  double _milesProgress(double currentOdometer) {
    if (lastServiceMiles == null || intervalMiles <= 0) return 0.0;
    return ((currentOdometer - lastServiceMiles!) / intervalMiles)
        .clamp(0.0, 2.0);
  }

  double get _timeProgress {
    if (lastServiceDate == null || intervalMonths == null || intervalMonths! <= 0) {
      return 0.0;
    }
    final totalDays = intervalMonths! * 30.44; // avg days per month
    final elapsed = DateTime.now().difference(lastServiceDate!).inDays;
    return (elapsed / totalDays).clamp(0.0, 2.0);
  }

  double _hoursProgress(double currentHours) {
    if (lastServiceHours == null || intervalHours == null || intervalHours! <= 0) {
      return 0.0;
    }
    return ((currentHours - lastServiceHours!) / intervalHours!)
        .clamp(0.0, 2.0);
  }

  /// The highest progress across all active triggers — "whichever comes first".
  double progressPercent(double currentOdometer, {double currentHours = 0}) {
    final candidates = <double>[
      _milesProgress(currentOdometer),
      _timeProgress,
      if (intervalHours != null) _hoursProgress(currentHours),
    ];
    return candidates.reduce(math.max);
  }

  /// Which trigger is driving the current urgency.
  UrgencyTrigger leadingTrigger(double currentOdometer,
      {double currentHours = 0}) {
    final mp = _milesProgress(currentOdometer);
    final tp = _timeProgress;
    final hp = intervalHours != null ? _hoursProgress(currentHours) : 0.0;

    if (mp >= tp && mp >= hp) return UrgencyTrigger.miles;
    if (tp >= mp && tp >= hp) return UrgencyTrigger.time;
    if (hp > 0) return UrgencyTrigger.hours;
    return UrgencyTrigger.none;
  }

  bool isOverdue(double currentOdometer, {double currentHours = 0}) {
    return progressPercent(currentOdometer, currentHours: currentHours) >= 1.0;
  }

  bool isDueSoon(double currentOdometer, {double currentHours = 0}) {
    final p = progressPercent(currentOdometer, currentHours: currentHours);
    return p >= 0.9 && p < 1.0;
  }

  /// Human-readable reason for the current urgency state.
  String urgencyReason(double currentOdometer, {double currentHours = 0}) {
    final trigger =
        leadingTrigger(currentOdometer, currentHours: currentHours);
    final overdue =
        isOverdue(currentOdometer, currentHours: currentHours);

    switch (trigger) {
      case UrgencyTrigger.miles:
        final next = nextDueMiles(currentOdometer);
        if (next == null) return '';
        final diff = (currentOdometer - next).round();
        return overdue
            ? '${diff.abs()} mi overdue'
            : '${diff.abs()} mi remaining';
      case UrgencyTrigger.time:
        final next = nextDueDate;
        if (next == null) return '';
        final days = next.difference(DateTime.now()).inDays;
        return overdue
            ? '${days.abs()} days overdue'
            : '$days days remaining';
      case UrgencyTrigger.hours:
        final next = nextDueHours;
        if (next == null) return '';
        final diff = (currentHours - next).round();
        return overdue
            ? '${diff.abs()} hrs overdue'
            : '${diff.abs()} hrs remaining';
      case UrgencyTrigger.none:
        return '';
    }
  }

  ServiceSchedule copyWith({
    String? id,
    String? vehicleId,
    String? serviceTypeId,
    String? name,
    int? intervalMiles,
    int? intervalMonths,
    int? intervalHours,
    double? lastServiceMiles,
    DateTime? lastServiceDate,
    double? lastServiceHours,
    String? lastServiceRecordId,
    bool? isEnabled,
    int? sortOrder,
  }) {
    return ServiceSchedule(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceTypeId: serviceTypeId ?? this.serviceTypeId,
      name: name ?? this.name,
      intervalMiles: intervalMiles ?? this.intervalMiles,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      intervalHours: intervalHours ?? this.intervalHours,
      lastServiceMiles: lastServiceMiles ?? this.lastServiceMiles,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      lastServiceHours: lastServiceHours ?? this.lastServiceHours,
      lastServiceRecordId: lastServiceRecordId ?? this.lastServiceRecordId,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'vehicleId': vehicleId,
      'serviceTypeId': serviceTypeId,
      'name': name,
      'intervalMiles': intervalMiles,
      'intervalMonths': intervalMonths,
      'intervalHours': intervalHours,
      'lastServiceMiles': lastServiceMiles,
      'lastServiceDate': lastServiceDate != null
          ? Timestamp.fromDate(lastServiceDate!)
          : null,
      'lastServiceHours': lastServiceHours,
      'lastServiceRecordId': lastServiceRecordId,
      'isEnabled': isEnabled,
      'sortOrder': sortOrder,
    };
  }

  factory ServiceSchedule.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceSchedule(
      id: doc.id,
      vehicleId: d['vehicleId'] as String? ?? '',
      serviceTypeId: d['serviceTypeId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      intervalMiles: (d['intervalMiles'] as num?)?.toInt() ?? 0,
      intervalMonths: (d['intervalMonths'] as num?)?.toInt(),
      intervalHours: (d['intervalHours'] as num?)?.toInt(),
      lastServiceMiles: (d['lastServiceMiles'] as num?)?.toDouble(),
      lastServiceDate: (d['lastServiceDate'] as Timestamp?)?.toDate(),
      lastServiceHours: (d['lastServiceHours'] as num?)?.toDouble(),
      lastServiceRecordId: d['lastServiceRecordId'] as String?,
      isEnabled: d['isEnabled'] as bool? ?? true,
      sortOrder: (d['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
