import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_job.dart';
import '../services/ai_job_service.dart';
import 'vehicle_provider.dart';

/// AI job service provider.
final aiJobServiceProvider = Provider<AiJobService>((ref) {
  return AiJobService();
});

/// Watch a specific AI job for real-time progress updates.
final aiJobProvider = StreamProvider.family<AiJob?, String>((ref, jobId) {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return const Stream.empty();

  final service = ref.watch(aiJobServiceProvider);
  return service.watchJob(uid, jobId);
});
