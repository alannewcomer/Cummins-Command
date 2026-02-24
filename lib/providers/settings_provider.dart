import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/diagnostic_service.dart';

/// Provider for the dev-logs cloud upload toggle.
/// Reads initial state from [DiagnosticService] (which loads from SharedPreferences).
final devLogsCloudProvider =
    NotifierProvider<DevLogsCloudNotifier, bool>(DevLogsCloudNotifier.new);

class DevLogsCloudNotifier extends Notifier<bool> {
  @override
  bool build() => diag.cloudUploadEnabled;

  Future<void> toggle(bool enabled) async {
    await diag.setCloudUploadEnabled(enabled);
    state = enabled;
  }
}
