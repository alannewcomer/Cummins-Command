import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/diagnostic_service.dart';

/// Provider for the dev-logs cloud upload toggle.
/// Reads initial state from [DiagnosticService] (which loads from SharedPreferences).
final devLogsCloudProvider =
    StateNotifierProvider<DevLogsCloudNotifier, bool>((ref) {
  return DevLogsCloudNotifier();
});

class DevLogsCloudNotifier extends StateNotifier<bool> {
  DevLogsCloudNotifier() : super(diag.cloudUploadEnabled);

  Future<void> toggle(bool enabled) async {
    await diag.setCloudUploadEnabled(enabled);
    state = enabled;
  }
}
