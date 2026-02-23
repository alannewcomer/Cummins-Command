import 'package:cloud_firestore/cloud_firestore.dart';

/// Granular permissions for a shared vehicle.
class SharePermissions {
  final bool viewLive;
  final bool viewHistory;
  final bool viewAI;
  final bool viewMaintenance;
  final bool editMaintenance;
  final bool manageDashboards;

  const SharePermissions({
    this.viewLive = false,
    this.viewHistory = false,
    this.viewAI = false,
    this.viewMaintenance = false,
    this.editMaintenance = false,
    this.manageDashboards = false,
  });

  SharePermissions copyWith({
    bool? viewLive,
    bool? viewHistory,
    bool? viewAI,
    bool? viewMaintenance,
    bool? editMaintenance,
    bool? manageDashboards,
  }) {
    return SharePermissions(
      viewLive: viewLive ?? this.viewLive,
      viewHistory: viewHistory ?? this.viewHistory,
      viewAI: viewAI ?? this.viewAI,
      viewMaintenance: viewMaintenance ?? this.viewMaintenance,
      editMaintenance: editMaintenance ?? this.editMaintenance,
      manageDashboards: manageDashboards ?? this.manageDashboards,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewLive': viewLive,
      'viewHistory': viewHistory,
      'viewAI': viewAI,
      'viewMaintenance': viewMaintenance,
      'editMaintenance': editMaintenance,
      'manageDashboards': manageDashboards,
    };
  }

  factory SharePermissions.fromMap(Map<String, dynamic> m) {
    return SharePermissions(
      viewLive: m['viewLive'] as bool? ?? false,
      viewHistory: m['viewHistory'] as bool? ?? false,
      viewAI: m['viewAI'] as bool? ?? false,
      viewMaintenance: m['viewMaintenance'] as bool? ?? false,
      editMaintenance: m['editMaintenance'] as bool? ?? false,
      manageDashboards: m['manageDashboards'] as bool? ?? false,
    );
  }
}

/// A record of vehicle sharing between users.
class ShareRecord {
  final String id;
  final String? sharedWithUserId;
  final String? sharedWithEmail;
  final SharePermissions permissions;
  final String status; // pending, accepted, revoked
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const ShareRecord({
    required this.id,
    this.sharedWithUserId,
    this.sharedWithEmail,
    this.permissions = const SharePermissions(),
    this.status = 'pending',
    this.inviteCode,
    required this.createdAt,
    this.acceptedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRevoked => status == 'revoked';

  ShareRecord copyWith({
    String? id,
    String? sharedWithUserId,
    String? sharedWithEmail,
    SharePermissions? permissions,
    String? status,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? acceptedAt,
  }) {
    return ShareRecord(
      id: id ?? this.id,
      sharedWithUserId: sharedWithUserId ?? this.sharedWithUserId,
      sharedWithEmail: sharedWithEmail ?? this.sharedWithEmail,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sharedWithUserId': sharedWithUserId,
      'sharedWithEmail': sharedWithEmail,
      'permissions': permissions.toMap(),
      'status': status,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
    };
  }

  factory ShareRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ShareRecord(
      id: doc.id,
      sharedWithUserId: d['sharedWithUserId'] as String?,
      sharedWithEmail: d['sharedWithEmail'] as String?,
      permissions: d['permissions'] != null
          ? SharePermissions.fromMap(d['permissions'] as Map<String, dynamic>)
          : const SharePermissions(),
      status: d['status'] as String? ?? 'pending',
      inviteCode: d['inviteCode'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }
}
