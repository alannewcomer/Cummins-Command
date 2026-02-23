import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/config/constants.dart';
import 'package:myapp/models/ai_job.dart';

/// Service for creating and monitoring AI processing jobs in Firestore.
///
/// Implements the reactive Firestore pattern:
/// 1. App creates a job document with type, params, and status='queued'
/// 2. Cloud Function (onDocumentCreated) picks up the job
/// 3. Cloud Function processes with Gemini, updating progress
/// 4. Client watches via snapshot listener for real-time progress
/// 5. Result is written back to the job document
///
/// Designed for use with Riverpod providers.
class AiJobService {
  final FirebaseFirestore _firestore;

  AiJobService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Track active snapshot subscriptions for cleanup
  final Map<String, StreamSubscription<DocumentSnapshot>> _subscriptions = {};

  // ─── Job Creation ───

  /// Create a new AI job and return its document ID.
  ///
  /// The job is created with status 'queued' and will be picked up
  /// by a Cloud Function that triggers on document creation.
  ///
  /// [userId] — the authenticated user's UID
  /// [type] — job type (e.g. 'drive_analysis', 'dashboard_generation')
  /// [vehicleId] — the vehicle this job relates to
  /// [params] — type-specific parameters for the Cloud Function
  ///
  /// Returns the Firestore document ID of the created job.
  Future<String> createJob(
    String userId,
    String type,
    String vehicleId,
    Map<String, dynamic> params,
  ) async {
    final job = AiJob(
      id: '', // Assigned by Firestore
      type: type,
      vehicleId: vehicleId,
      parameters: params,
      status: 'queued',
      progress: 0.0,
      createdAt: DateTime.now(),
    );

    final docRef = await _jobCollection(userId).add(job.toFirestore());
    return docRef.id;
  }

  /// Create a drive analysis job for a specific drive session.
  Future<String> createDriveAnalysisJob(
    String userId,
    String vehicleId,
    String driveId, {
    List<String>? focusAreas,
  }) async {
    return createJob(userId, 'drive_analysis', vehicleId, {
      'driveId': driveId,
      'focusAreas': focusAreas ?? ['anomalies', 'efficiency', 'health'],
    });
  }

  /// Create a predictive maintenance job.
  Future<String> createMaintenancePredictionJob(
    String userId,
    String vehicleId, {
    int? lookbackDays,
  }) async {
    return createJob(userId, 'predictive_maintenance', vehicleId, {
      'lookbackDays': lookbackDays ?? 90,
    });
  }

  /// Create a dashboard generation job from a natural language prompt.
  Future<String> createDashboardGenerationJob(
    String userId,
    String vehicleId,
    String prompt,
  ) async {
    return createJob(userId, 'dashboard_generation', vehicleId, {
      'prompt': prompt,
    });
  }

  /// Create a custom analysis query job.
  Future<String> createCustomQueryJob(
    String userId,
    String vehicleId,
    String query, {
    Map<String, dynamic>? additionalContext,
  }) async {
    return createJob(userId, 'custom_query', vehicleId, {
      'query': query,
      if (additionalContext != null) ...additionalContext,
    });
  }

  // ─── Job Monitoring ───

  /// Watch a specific job for real-time status and progress updates.
  ///
  /// Returns a stream that emits [AiJob] updates whenever the Firestore
  /// document changes (e.g. status transitions, progress increments,
  /// result writing).
  ///
  /// The stream completes when the job reaches a terminal state
  /// (complete or failed).
  Stream<AiJob> watchJob(String userId, String jobId) {
    final controller = StreamController<AiJob>();

    final subscription = _jobCollection(userId)
        .doc(jobId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          controller.addError(
            StateError('Job $jobId not found'),
          );
          controller.close();
          return;
        }

        final job = AiJob.fromFirestore(snapshot);
        controller.add(job);

        // Auto-close when job reaches terminal state
        if (job.isFinished) {
          // Allow one last update to propagate before closing
          Future<void>.delayed(const Duration(milliseconds: 100), () {
            controller.close();
          });
        }
      },
      onError: (Object error) {
        controller.addError(error);
        controller.close();
      },
    );

    // Track for cleanup
    _subscriptions[jobId] = subscription;

    // Clean up subscription when stream is closed
    controller.onCancel = () {
      subscription.cancel();
      _subscriptions.remove(jobId);
    };

    return controller.stream;
  }

  /// Get a single job's current state.
  Future<AiJob?> getJob(String userId, String jobId) async {
    final doc = await _jobCollection(userId).doc(jobId).get();
    if (!doc.exists) return null;
    return AiJob.fromFirestore(doc);
  }

  /// List recent jobs for a user, optionally filtered by type or status.
  Future<List<AiJob>> listJobs(
    String userId, {
    String? type,
    String? status,
    int limit = 20,
  }) async {
    Query query = _jobCollection(userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => AiJob.fromFirestore(doc)).toList();
  }

  /// List active (non-terminal) jobs for a user.
  Future<List<AiJob>> listActiveJobs(String userId) async {
    // Firestore doesn't support NOT IN efficiently, so query both states
    final queuedFuture = _jobCollection(userId)
        .where('status', isEqualTo: 'queued')
        .get();
    final processingFuture = _jobCollection(userId)
        .where('status', isEqualTo: 'processing')
        .get();

    final results = await Future.wait([queuedFuture, processingFuture]);
    final jobs = <AiJob>[];
    for (final snapshot in results) {
      jobs.addAll(snapshot.docs.map((doc) => AiJob.fromFirestore(doc)));
    }

    // Sort by creation time
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  /// Cancel a pending job (only works if status is still 'queued').
  ///
  /// Sets the status to 'failed' with an error message.
  Future<bool> cancelJob(String userId, String jobId) async {
    try {
      await _jobCollection(userId).doc(jobId).update({
        'status': 'failed',
        'error': 'Cancelled by user',
        'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Cleanup ───

  /// Cancel all active snapshot subscriptions.
  void cancelAllWatchers() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Dispose all resources.
  void dispose() {
    cancelAllWatchers();
  }

  // ─── Private ───

  CollectionReference _jobCollection(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.aiJobsSubcollection);
  }
}
