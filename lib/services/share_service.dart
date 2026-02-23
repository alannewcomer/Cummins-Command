import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/config/constants.dart';
import 'package:myapp/models/share_record.dart';

/// Vehicle sharing service handling invite creation, acceptance, and revocation.
///
/// Share flow:
/// 1. Owner creates a share invite (by email or generates a share code)
/// 2. Recipient receives the invite and accepts with their account
/// 3. Accepted shares grant read access to the vehicle's data
/// 4. Owner can revoke at any time; recipient can leave
///
/// Data model: ShareRecords live under
/// `users/{ownerId}/vehicles/{vehicleId}/sharing/{shareId}`
///
/// Designed for use with Riverpod providers.
class ShareService {
  final FirebaseFirestore _firestore;

  ShareService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Create Share ───

  /// Create a share invite by email.
  ///
  /// The recipient doesn't need an account yet — the invite is stored
  /// with their email and matched when they sign up or sign in.
  Future<ShareRecord> createInviteByEmail(
    String ownerUserId,
    String vehicleId,
    String email, {
    SharePermissions permissions = const SharePermissions(
      viewLive: true,
      viewHistory: true,
      viewAI: true,
      viewMaintenance: true,
    ),
  }) async {
    // Check for existing pending invite to same email
    final existing = await _sharingCollection(ownerUserId, vehicleId)
        .where('sharedWithEmail', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) {
      return ShareRecord.fromFirestore(existing.docs.first);
    }

    final code = _generateShareCode();

    final record = ShareRecord(
      id: '',
      sharedWithEmail: email,
      permissions: permissions,
      status: 'pending',
      inviteCode: code,
      createdAt: DateTime.now(),
    );

    final docRef = await _sharingCollection(ownerUserId, vehicleId)
        .add(record.toFirestore());

    // Also create a global invite lookup document for code-based acceptance
    await _firestore.collection('shareInvites').doc(code).set({
      'ownerUserId': ownerUserId,
      'vehicleId': vehicleId,
      'shareId': docRef.id,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ShareRecord.fromFirestore(await docRef.get());
  }

  /// Generate a share link with a unique invite code.
  ///
  /// Returns the invite code that can be shared via any messaging platform.
  /// The recipient enters this code to gain access.
  Future<ShareInviteResult> generateShareLink(
    String ownerUserId,
    String vehicleId, {
    SharePermissions permissions = const SharePermissions(
      viewLive: true,
      viewHistory: true,
    ),
    Duration? expiresIn,
  }) async {
    final code = _generateShareCode();
    final expiresAt = expiresIn != null
        ? DateTime.now().add(expiresIn)
        : DateTime.now().add(const Duration(days: 7)); // Default 7 day expiry

    final record = ShareRecord(
      id: '',
      permissions: permissions,
      status: 'pending',
      inviteCode: code,
      createdAt: DateTime.now(),
    );

    final docRef = await _sharingCollection(ownerUserId, vehicleId)
        .add(record.toFirestore());

    // Global invite lookup
    await _firestore.collection('shareInvites').doc(code).set({
      'ownerUserId': ownerUserId,
      'vehicleId': vehicleId,
      'shareId': docRef.id,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ShareInviteResult(
      shareId: docRef.id,
      inviteCode: code,
      expiresAt: expiresAt,
    );
  }

  // ─── Accept Share ───

  /// Accept a share invite using an invite code.
  ///
  /// Validates the code, checks expiry, and updates the share record
  /// with the accepting user's ID.
  Future<ShareAcceptResult> acceptByCode(
    String recipientUserId,
    String code,
  ) async {
    // Look up the invite
    final inviteDoc =
        await _firestore.collection('shareInvites').doc(code).get();

    if (!inviteDoc.exists) {
      return const ShareAcceptResult(
        success: false,
        error: 'Invalid invite code',
      );
    }

    final inviteData = inviteDoc.data()!;
    final ownerUserId = inviteData['ownerUserId'] as String;
    final vehicleId = inviteData['vehicleId'] as String;
    final shareId = inviteData['shareId'] as String;

    // Check expiry
    final expiresAt = (inviteData['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      return const ShareAcceptResult(
        success: false,
        error: 'Invite has expired',
      );
    }

    // Cannot share with yourself
    if (recipientUserId == ownerUserId) {
      return const ShareAcceptResult(
        success: false,
        error: 'Cannot accept your own share invite',
      );
    }

    // Update the share record
    final shareRef =
        _sharingCollection(ownerUserId, vehicleId).doc(shareId);
    final shareDoc = await shareRef.get();

    if (!shareDoc.exists) {
      return const ShareAcceptResult(
        success: false,
        error: 'Share record not found',
      );
    }

    final shareRecord = ShareRecord.fromFirestore(shareDoc);
    if (shareRecord.isRevoked) {
      return const ShareAcceptResult(
        success: false,
        error: 'This share has been revoked',
      );
    }
    if (shareRecord.isAccepted) {
      return const ShareAcceptResult(
        success: false,
        error: 'This invite has already been accepted',
      );
    }

    // Accept the share
    await shareRef.update({
      'sharedWithUserId': recipientUserId,
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Create a reverse lookup so the recipient can find their shared vehicles
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(recipientUserId)
        .collection('sharedWithMe')
        .doc('${ownerUserId}_$vehicleId')
        .set({
      'ownerUserId': ownerUserId,
      'vehicleId': vehicleId,
      'shareId': shareId,
      'permissions': shareRecord.permissions.toMap(),
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Clean up the global invite
    await _firestore.collection('shareInvites').doc(code).delete();

    return ShareAcceptResult(
      success: true,
      ownerUserId: ownerUserId,
      vehicleId: vehicleId,
    );
  }

  // ─── Revoke / Leave ───

  /// Revoke a share (called by the vehicle owner).
  Future<bool> revokeShare(
    String ownerUserId,
    String vehicleId,
    String shareId,
  ) async {
    try {
      final shareRef =
          _sharingCollection(ownerUserId, vehicleId).doc(shareId);
      final shareDoc = await shareRef.get();

      if (!shareDoc.exists) return false;

      final record = ShareRecord.fromFirestore(shareDoc);

      // Update status
      await shareRef.update({'status': 'revoked'});

      // Remove reverse lookup if the share was accepted
      if (record.sharedWithUserId != null) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(record.sharedWithUserId)
            .collection('sharedWithMe')
            .doc('${ownerUserId}_$vehicleId')
            .delete();
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Leave a shared vehicle (called by the recipient).
  Future<bool> leaveShare(
    String recipientUserId,
    String ownerUserId,
    String vehicleId,
  ) async {
    try {
      // Find the share record
      final shares = await _sharingCollection(ownerUserId, vehicleId)
          .where('sharedWithUserId', isEqualTo: recipientUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      if (shares.docs.isEmpty) return false;

      // Update all matching shares to revoked
      final batch = _firestore.batch();
      for (final doc in shares.docs) {
        batch.update(doc.reference, {'status': 'revoked'});
      }
      await batch.commit();

      // Remove reverse lookup
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(recipientUserId)
          .collection('sharedWithMe')
          .doc('${ownerUserId}_$vehicleId')
          .delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Queries ───

  /// Get all shares for a vehicle (owner view).
  Future<List<ShareRecord>> getSharesForVehicle(
    String ownerUserId,
    String vehicleId,
  ) async {
    final snapshot = await _sharingCollection(ownerUserId, vehicleId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ShareRecord.fromFirestore(doc))
        .toList();
  }

  /// Get active shares for a vehicle (owner view, accepted only).
  Future<List<ShareRecord>> getActiveShares(
    String ownerUserId,
    String vehicleId,
  ) async {
    final snapshot = await _sharingCollection(ownerUserId, vehicleId)
        .where('status', isEqualTo: 'accepted')
        .get();

    return snapshot.docs
        .map((doc) => ShareRecord.fromFirestore(doc))
        .toList();
  }

  /// Get all vehicles shared with a user (recipient view).
  Future<List<SharedVehicleRef>> getSharedWithMe(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('sharedWithMe')
        .get();

    return snapshot.docs.map((doc) {
      final d = doc.data();
      return SharedVehicleRef(
        ownerUserId: d['ownerUserId'] as String? ?? '',
        vehicleId: d['vehicleId'] as String? ?? '',
        shareId: d['shareId'] as String? ?? '',
        permissions: d['permissions'] != null
            ? SharePermissions.fromMap(d['permissions'] as Map<String, dynamic>)
            : const SharePermissions(),
      );
    }).toList();
  }

  /// Get pending invites for a user by email.
  Future<List<PendingInvite>> getPendingInvitesForEmail(String email) async {
    final snapshot = await _firestore
        .collection('shareInvites')
        .where('email', isEqualTo: email)
        .get();

    return snapshot.docs.map((doc) {
      final d = doc.data();
      return PendingInvite(
        code: doc.id,
        ownerUserId: d['ownerUserId'] as String? ?? '',
        vehicleId: d['vehicleId'] as String? ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
        expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  // ─── Private ───

  CollectionReference _sharingCollection(
    String ownerUserId,
    String vehicleId,
  ) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(ownerUserId)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(vehicleId)
        .collection(AppConstants.sharingSubcollection);
  }

  /// Generate a 6-character alphanumeric share code.
  String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Exclude confusing chars
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

// ─── Result Types ───

/// Result of generating a share invite link.
class ShareInviteResult {
  final String shareId;
  final String inviteCode;
  final DateTime expiresAt;

  const ShareInviteResult({
    required this.shareId,
    required this.inviteCode,
    required this.expiresAt,
  });
}

/// Result of accepting a share invite.
class ShareAcceptResult {
  final bool success;
  final String? ownerUserId;
  final String? vehicleId;
  final String? error;

  const ShareAcceptResult({
    required this.success,
    this.ownerUserId,
    this.vehicleId,
    this.error,
  });
}

/// Reference to a vehicle shared with the current user.
class SharedVehicleRef {
  final String ownerUserId;
  final String vehicleId;
  final String shareId;
  final SharePermissions permissions;

  const SharedVehicleRef({
    required this.ownerUserId,
    required this.vehicleId,
    required this.shareId,
    required this.permissions,
  });
}

/// A pending share invite found by email.
class PendingInvite {
  final String code;
  final String ownerUserId;
  final String vehicleId;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const PendingInvite({
    required this.code,
    required this.ownerUserId,
    required this.vehicleId,
    this.createdAt,
    this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
