import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/drives_provider.dart';
import '../../providers/live_data_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/bluetooth_service.dart';
import '../../services/diagnostic_service.dart';
import '../../widgets/common/glass_card.dart';

/// Full-featured Bluetooth setup screen with guided connection flow,
/// auto-reconnect controls, and connection health monitoring.
class BluetoothSetupScreen extends ConsumerStatefulWidget {
  const BluetoothSetupScreen({super.key});

  @override
  ConsumerState<BluetoothSetupScreen> createState() => _BluetoothSetupScreenState();
}

class _BluetoothSetupScreenState extends ConsumerState<BluetoothSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  String? _connectingAddress;
  String? _errorMessage;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btState = ref.watch(bluetoothStateProvider);
    final devices = ref.watch(bluetoothDevicesProvider);
    final btService = ref.watch(bluetoothServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('OBD Connection', style: AppTypography.displaySmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Connection Status Card ──
          _buildStatusCard(btState, btService),
          const SizedBox(height: AppSpacing.xl),

          // ── Setup Instructions ──
          _buildInstructionsCard(),
          const SizedBox(height: AppSpacing.xl),

          // ── Scan / Devices Section ──
          _buildScanSection(btState, devices, btService),
          const SizedBox(height: AppSpacing.xl),

          // ── Auto-Recovery Settings ──
          _buildAutoRecoveryCard(btService),
          const SizedBox(height: AppSpacing.xl),

          // ── Connection Health ──
          _buildHealthCard(btState),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      AsyncValue<BluetoothConnectionState> btState, BluetoothService btService) {
    final state = btState.value ?? BluetoothConnectionState.disconnected;
    final sleepPhase = ref.watch(sleepPhaseProvider);
    final isSleeping = state == BluetoothConnectionState.disconnected &&
        sleepPhase != SleepReconnectPhase.none;

    final sleepLabel = switch (sleepPhase) {
      SleepReconnectPhase.phaseA => 'Waiting for engine — checking every 30s',
      SleepReconnectPhase.phaseB => 'Adapter entering deep sleep — quiet period',
      SleepReconnectPhase.phaseC => 'Background monitoring — checking every 60s',
      SleepReconnectPhase.none => '',
    };

    final (statusText, statusColor, statusIcon) = isSleeping
        ? (sleepLabel, AppColors.warning, Icons.bedtime_outlined)
        : switch (state) {
            BluetoothConnectionState.connected => (
                'Connected to OBDLink MX+',
                AppColors.success,
                Icons.bluetooth_connected,
              ),
            BluetoothConnectionState.connecting => (
                'Connecting...',
                AppColors.warning,
                Icons.bluetooth_searching,
              ),
            BluetoothConnectionState.scanning => (
                'Scanning for devices...',
                AppColors.dataAccent,
                Icons.bluetooth_searching,
              ),
            BluetoothConnectionState.error => (
                _errorMessage ?? 'Connection error',
                AppColors.critical,
                Icons.bluetooth_disabled,
              ),
            BluetoothConnectionState.disconnected => (
                'Not connected',
                AppColors.textTertiary,
                Icons.bluetooth,
              ),
          };

    return GlassCard(
      glowColor: statusColor,
      child: Column(
        children: [
          // Pulsing Bluetooth icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.1 * _pulseAnimation.value),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3 * _pulseAnimation.value),
                    width: 2,
                  ),
                ),
                child: Icon(statusIcon, size: 36, color: statusColor),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(statusText, style: AppTypography.labelLarge.copyWith(color: statusColor)),
          if (state == BluetoothConnectionState.connected) ...[
            const SizedBox(height: AppSpacing.lg),
            if (_isInitializing)
              Column(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Initializing OBD adapter...', style: AppTypography.bodySmall),
                ],
              )
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Start Monitoring'),
                onPressed: () => context.go('/'),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => btService.disconnect(),
              child: Text('Disconnect', style: TextStyle(color: AppColors.critical)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.dataAccent),
              const SizedBox(width: AppSpacing.sm),
              Text('Setup Guide', style: AppTypography.labelLarge.copyWith(color: AppColors.dataAccent)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InstructionStep(
            number: 1,
            text: 'Plug OBDLink MX+ into the OBD2 port under the dashboard',
          ),
          _InstructionStep(
            number: 2,
            text: 'Turn the ignition ON (engine can be off or running)',
          ),
          _InstructionStep(
            number: 3,
            text: 'The OBDLink LED should blink — it\'s ready to pair',
          ),
          _InstructionStep(
            number: 4,
            text: 'Tap "Scan for Devices" below and select OBDLink MX+',
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'If the adapter doesn\'t appear, ensure Bluetooth is enabled in '
                    'your phone settings and the OBDLink is powered (LED blinking).',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanSection(AsyncValue<BluetoothConnectionState> btState,
      List<BluetoothDeviceInfo> devices, BluetoothService btService) {
    final state = btState.value ?? BluetoothConnectionState.disconnected;
    final isScanning = state == BluetoothConnectionState.scanning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Devices', padding: EdgeInsets.zero),
            ElevatedButton.icon(
              icon: isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search, size: 18),
              label: Text(isScanning ? 'Scanning...' : 'Scan'),
              onPressed: isScanning
                  ? null
                  : () async {
                      setState(() => _errorMessage = null);
                      final granted = await _ensureBluetoothPermissions();
                      if (!granted) return;
                      ref.read(bluetoothDevicesProvider.notifier).startScan();
                    },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        if (devices.isEmpty && !isScanning)
          GlassCard(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bluetooth_searching,
                    size: 40,
                    color: AppColors.textTertiary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('No devices found', style: AppTypography.bodyMedium),
                  Text('Tap Scan to search for OBDLink MX+', style: AppTypography.bodySmall),
                ],
              ),
            ),
          ),

        // Device list
        ...devices.map((device) {
          final isConnecting = _connectingAddress == device.address;
          final isObdLink = device.name.toLowerCase().contains('obd') ||
              device.name.toLowerCase().contains('elm');

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: GlassCard(
              onTap: () => _connectToDevice(device, btService),
              borderColor: isObdLink
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : null,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isObdLink
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isObdLink ? Icons.directions_car : Icons.bluetooth,
                      size: 20,
                      color: isObdLink ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name.isEmpty ? 'Unknown Device' : device.name,
                          style: AppTypography.labelMedium.copyWith(
                            color: isObdLink ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        Text(device.address, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  if (isObdLink)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDim,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'OBD',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (isConnecting) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAutoRecoveryCard(BluetoothService btService) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.autorenew, size: 18, color: AppColors.dataAccent),
              const SizedBox(width: AppSpacing.sm),
              Text('Auto-Recovery',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.dataAccent)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'If the Bluetooth connection drops during monitoring, '
            'the app will automatically attempt to reconnect with '
            'exponential backoff (3s → 4.5s → 6.75s...) up to 10 attempts.',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Auto-Reconnect', style: AppTypography.labelMedium),
              Switch(
                value: true,
                onChanged: (val) {
                  if (val) {
                    btService.startAutoReconnect();
                  }
                },
              ),
            ],
          ),
          const Divider(color: AppColors.surfaceBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Max Retry Attempts', style: AppTypography.labelMedium),
              Text('10', style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Initial Retry Delay', style: AppTypography.labelMedium),
              Text('3 sec', style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Backoff Multiplier', style: AppTypography.labelMedium),
              Text('1.5x', style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(AsyncValue<BluetoothConnectionState> btState) {
    final state = btState.value ?? BluetoothConnectionState.disconnected;
    final isConnected = state == BluetoothConnectionState.connected;
    final sleepPhase = ref.watch(sleepPhaseProvider);
    final isSleeping = !isConnected && sleepPhase != SleepReconnectPhase.none;
    final btService = ref.watch(bluetoothServiceProvider);

    final statusValue = isConnected
        ? 'Connected'
        : isSleeping
            ? 'Sleep (${sleepPhase.name})'
            : 'Disconnected';
    final statusColor = isConnected
        ? AppColors.success
        : isSleeping
            ? AppColors.warning
            : AppColors.textTertiary;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 18, color: AppColors.dataAccent),
              const SizedBox(width: AppSpacing.sm),
              Text('Connection Health',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.dataAccent)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _HealthRow(
            label: 'Status',
            value: statusValue,
            color: statusColor,
          ),
          _HealthRow(
            label: 'Protocol',
            value: isConnected ? 'OBD2 (ISO 15765-4)' : '--',
            color: AppColors.dataAccent,
          ),
          _HealthRow(
            label: 'Ping Interval',
            value: '10 sec',
            color: AppColors.dataAccent,
          ),
          _HealthRow(
            label: 'Reconnect Attempts',
            value: '${btService.reconnectAttempts}',
            color: AppColors.dataAccent,
          ),
          if (isSleeping) ...[
            const Divider(color: AppColors.surfaceBorder),
            _HealthRow(
              label: 'Sleep Phase',
              value: switch (sleepPhase) {
                SleepReconnectPhase.phaseA => 'A — Quick restart (30s)',
                SleepReconnectPhase.phaseB => 'B — Quiet period',
                SleepReconnectPhase.phaseC => 'C — Background (60s)',
                SleepReconnectPhase.none => '--',
              },
              color: AppColors.warning,
            ),
            _HealthRow(
              label: 'Auto-Reconnect',
              value: 'Active',
              color: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }

  /// Request Bluetooth + location runtime permissions (Android 12+).
  /// Returns true if all required permissions are granted.
  Future<bool> _ensureBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    if (!allGranted) {
      final denied = statuses.entries
          .where((e) => !e.value.isGranted && !e.value.isLimited)
          .map((e) => e.key.toString().split('.').last)
          .join(', ');

      setState(() {
        _errorMessage = 'Permissions denied: $denied. '
            'Please grant Bluetooth permissions in Settings.';
      });

      // If permanently denied, offer to open app settings
      if (statuses.values.any((s) => s.isPermanentlyDenied)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bluetooth permissions permanently denied'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
      }
      return false;
    }
    return true;
  }

  Future<void> _connectToDevice(
      BluetoothDeviceInfo device, BluetoothService btService) async {
    setState(() {
      _connectingAddress = device.address;
      _errorMessage = null;
    });
    try {
      final granted = await _ensureBluetoothPermissions();
      if (!granted) {
        setState(() => _connectingAddress = null);
        return;
      }
      diag.info('BT', 'Connecting to ${device.name}', device.address);
      final connected = await btService.connect(device.address);
      if (!connected) {
        diag.error('BT', 'Connection failed', btService.lastError);
        setState(() {
          _errorMessage = btService.lastError ?? 'Connection refused';
          _connectingAddress = null;
        });
        return;
      }
      diag.info('BT', 'Bluetooth connected');

      setState(() => _isInitializing = true);

      // Initialize OBD adapter with real AT command sequence
      final obdService = ref.read(obdServiceProvider);
      final success = await obdService.initialize();

      if (!success) {
        diag.error('BT', 'OBD init failed', obdService.lastError);
        setState(() {
          _isInitializing = false;
          _errorMessage = obdService.lastError ?? 'OBD initialization failed';
          _connectingAddress = null;
        });
        return;
      }

      // Start polling PIDs now that OBD is ready
      obdService.startPolling();
      diag.info('BT', 'OBD polling started');

      // Auto-start recording to Firestore — only if engine is confirmed running
      // (RPM gate prevents recording bogus data during key-on-engine-off)
      final recorder = ref.read(driveRecorderProvider);
      final uid = ref.read(authStateProvider).value?.uid;
      final vehicle = ref.read(activeVehicleProvider);
      final currentRpm = obdService.liveData['rpm'] ?? obdService.liveData['engineSpeed'];
      diag.debug('BT', 'Auto-record check', 'uid=$uid vehicle=${vehicle?.id} rpm=$currentRpm');
      if (uid != null && vehicle != null && !recorder.isRecording &&
          currentRpm != null && currentRpm > AppConstants.engineOffRpmThreshold) {
        final driveId = await recorder.startRecording(vehicle.id, userId: uid);
        if (driveId != null) {
          ref.read(isRecordingProvider.notifier).setRecording(true);
          ref.read(activeDriveIdProvider.notifier).setDriveId(driveId);
          diag.info('BT', 'Auto-recording started', 'driveId=$driveId');
        } else {
          diag.warn('BT', 'Auto-record returned null driveId');
        }
      } else if (currentRpm == null || currentRpm <= AppConstants.engineOffRpmThreshold) {
        diag.info('BT', 'Auto-record deferred — engine not confirmed running',
            'rpm=$currentRpm (lifecycle provider will start when engine runs)');
      }

      // Enable auto-reconnect after successful init
      btService.startAutoReconnect();
      setState(() {
        _isInitializing = false;
        _connectingAddress = null;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to connect: $e';
        _connectingAddress = null;
      });
    }
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                '$number',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: AppTypography.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.labelMedium),
          Text(value, style: AppTypography.dataSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
