import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme.dart';
import '../../config/constants.dart';
import '../../models/vehicle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/bluetooth_ux_provider.dart';
import '../../providers/drives_provider.dart';
import '../../providers/live_data_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/bluetooth_service.dart';
import '../../services/diagnostic_service.dart';
import '../../widgets/common/glass_card.dart';

/// Full-featured Bluetooth setup screen with context-aware UX:
/// - New setup: full scan flow with instructions
/// - Known adapter: one-tap reconnect card
/// - Sleep phases: status card with phase info
/// - Connected: green status with monitoring controls
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
    final uxState = ref.watch(bluetoothUxStateProvider);

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
        children: _buildBodyForState(uxState),
      ),
    );
  }

  List<Widget> _buildBodyForState(BluetoothUxState uxState) {
    return switch (uxState) {
      BluetoothUxState.newSetup => _buildNewSetupBody(),
      BluetoothUxState.knownDisconnected => _buildKnownAdapterBody(),
      BluetoothUxState.scanning => _buildNewSetupBody(),
      BluetoothUxState.connecting => _buildConnectingBody(),
      BluetoothUxState.connected => _buildConnectedBody(),
      BluetoothUxState.sleepPhaseA ||
      BluetoothUxState.sleepPhaseB ||
      BluetoothUxState.sleepPhaseC => _buildSleepBody(uxState),
      BluetoothUxState.error => _buildErrorBody(),
    };
  }

  // ─── New Setup Body (first-time pairing) ───

  List<Widget> _buildNewSetupBody() {
    final btState = ref.watch(bluetoothStateProvider);
    final devices = ref.watch(bluetoothDevicesProvider);
    final btService = ref.watch(bluetoothServiceProvider);

    return [
      _buildStatusIcon(
        Icons.bluetooth,
        AppColors.dataAccent,
        'Ready to pair',
      ),
      const SizedBox(height: AppSpacing.xl),
      _buildInstructionsCard(),
      const SizedBox(height: AppSpacing.xl),
      _buildScanSection(btState, devices, btService),
      const SizedBox(height: AppSpacing.xl),
      _buildAutoRecoveryCard(btService),
    ];
  }

  // ─── Known Adapter Body (reconnect) ───

  List<Widget> _buildKnownAdapterBody() {
    final adapter = ref.watch(savedAdapterProvider);
    final btService = ref.watch(bluetoothServiceProvider);
    if (adapter == null) return _buildNewSetupBody();

    return [
      _buildAdapterInfoCard(adapter),
      const SizedBox(height: AppSpacing.xl),

      // Reconnect button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.bluetooth_searching, size: 20),
          label: const Text('Reconnect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
          ),
          onPressed: () => _reconnectToAdapter(adapter, btService),
        ),
      ),
      const SizedBox(height: AppSpacing.md),

      // Secondary actions
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Use Different'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.surfaceBorder),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              onPressed: _startFreshScan,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.link_off, size: 16),
              label: const Text('Forget'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.critical,
                side: BorderSide(color: AppColors.critical.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              onPressed: _forgetAdapter,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      _buildAutoRecoveryCard(btService),
    ];
  }

  // ─── Connecting Body ───

  List<Widget> _buildConnectingBody() {
    final adapter = ref.watch(savedAdapterProvider);

    return [
      if (adapter != null) ...[
        _buildAdapterInfoCard(adapter),
        const SizedBox(height: AppSpacing.xl),
      ],
      _buildStatusIcon(
        Icons.bluetooth_searching,
        AppColors.warning,
        _isInitializing ? 'Initializing OBD adapter...' : 'Connecting...',
        pulsing: true,
      ),
    ];
  }

  // ─── Connected Body ───

  List<Widget> _buildConnectedBody() {
    final adapter = ref.watch(savedAdapterProvider);
    final btService = ref.watch(bluetoothServiceProvider);

    return [
      if (adapter != null) ...[
        _buildAdapterInfoCard(adapter, connected: true),
        const SizedBox(height: AppSpacing.xl),
      ],
      _buildStatusIcon(
        Icons.bluetooth_connected,
        AppColors.success,
        'Connected to OBDLink MX+',
      ),
      const SizedBox(height: AppSpacing.xl),
      if (_isInitializing)
        const Center(
          child: Column(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: AppSpacing.sm),
              Text('Initializing OBD adapter...'),
            ],
          ),
        )
      else ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Start Monitoring'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            onPressed: () => context.go('/'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: () => btService.disconnect(),
            child: Text('Disconnect', style: TextStyle(color: AppColors.critical)),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      _buildHealthCard(true),
    ];
  }

  // ─── Sleep Body ───

  List<Widget> _buildSleepBody(BluetoothUxState uxState) {
    final btService = ref.watch(bluetoothServiceProvider);
    final adapter = ref.watch(savedAdapterProvider);

    final (phaseLabel, phaseDescription) = switch (uxState) {
      BluetoothUxState.sleepPhaseA => (
          'Phase A — Quick Restart Detection',
          'Checking every 30s for engine restart. '
              'If you just stopped at a gas station, the adapter will reconnect automatically.',
        ),
      BluetoothUxState.sleepPhaseB => (
          'Phase B — Quiet Period',
          'Letting the OBDLink MX+ BatterySaver fully power down. '
              'No connection attempts during this window to preserve truck battery.',
        ),
      BluetoothUxState.sleepPhaseC => (
          'Phase C — Background Monitoring',
          'Checking every 60s for engine restart. '
              'Connection attempts fail instantly when the adapter is sleeping — zero battery impact.',
        ),
      _ => ('', ''),
    };

    final elapsed = btService.sleepDisconnectTime != null
        ? DateTime.now().difference(btService.sleepDisconnectTime!)
        : Duration.zero;
    final elapsedText = elapsed.inMinutes > 0
        ? '${elapsed.inMinutes}m ago'
        : '${elapsed.inSeconds}s ago';

    return [
      if (adapter != null) ...[
        _buildAdapterInfoCard(adapter),
        const SizedBox(height: AppSpacing.xl),
      ],

      // Sleep status card
      GlassCard(
        glowColor: AppColors.dataAccent.withValues(alpha: 0.3),
        borderColor: AppColors.dataAccent.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) => Icon(
                    Icons.bedtime_outlined,
                    size: 20,
                    color: AppColors.dataAccent.withValues(
                        alpha: 0.4 + 0.6 * _pulseAnimation.value),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Adapter Sleeping',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.dataAccent),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(phaseLabel, style: AppTypography.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(phaseDescription, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Disconnected', style: AppTypography.labelSmall),
                Text(elapsedText,
                    style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reconnect attempts', style: AppTypography.labelSmall),
                Text('${btService.sleepReconnectAttempts}',
                    style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xl),

      // Manual reconnect
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.bluetooth_searching, size: 18),
          label: const Text('Try Reconnecting Now'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.dataAccent,
            side: BorderSide(color: AppColors.dataAccent.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          ),
          onPressed: () {
            final address = adapter?.address ?? btService.connectedAddress;
            if (address != null) {
              btService.connect(address);
            }
          },
        ),
      ),
    ];
  }

  // ─── Error Body ───

  List<Widget> _buildErrorBody() {
    final btService = ref.watch(bluetoothServiceProvider);
    final adapter = ref.watch(savedAdapterProvider);

    return [
      _buildStatusIcon(
        Icons.bluetooth_disabled,
        AppColors.critical,
        _errorMessage ?? btService.lastError ?? 'Connection error',
      ),
      const SizedBox(height: AppSpacing.xl),

      if (adapter != null) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            onPressed: () => _reconnectToAdapter(adapter, btService),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Scan for Devices'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.surfaceBorder),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          ),
          onPressed: _startFreshScan,
        ),
      ),
    ];
  }

  // ─── Shared Widgets ───

  Widget _buildAdapterInfoCard(ObdAdapter adapter, {bool connected = false}) {
    final glowColor = connected ? AppColors.success : AppColors.primary;
    final pairedDate = DateFormat('MMM d, yyyy').format(adapter.pairedAt);

    return GlassCard(
      glowColor: glowColor,
      borderColor: glowColor.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              connected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: glowColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adapter.name,
                  style: AppTypography.labelLarge.copyWith(color: glowColor),
                ),
                const SizedBox(height: 2),
                Text(adapter.type, style: AppTypography.bodySmall),
                Text(
                  '${adapter.address}  •  Paired $pairedDate',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: Text(
                'LIVE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(IconData icon, Color color, String text,
      {bool pulsing = false}) {
    return GlassCard(
      glowColor: color,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final alpha = pulsing ? _pulseAnimation.value : 1.0;
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1 * alpha),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3 * alpha),
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 36, color: color),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(text, style: AppTypography.labelLarge.copyWith(color: color),
              textAlign: TextAlign.center),
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
              onPressed: isScanning ? null : () => _startFreshScan(),
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

  Widget _buildHealthCard(bool isConnected) {
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
            value: isConnected ? 'Connected' : 'Disconnected',
            color: isConnected ? AppColors.success : AppColors.textTertiary,
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
            label: 'Reconnect Count',
            value: '0',
            color: AppColors.dataAccent,
          ),
        ],
      ),
    );
  }

  // ─── Actions ───

  Future<void> _reconnectToAdapter(ObdAdapter adapter, BluetoothService btService) async {
    final granted = await _ensureBluetoothPermissions();
    if (!granted) return;
    // Connect directly — no scan needed
    final device = BluetoothDeviceInfo(name: adapter.name, address: adapter.address);
    await _connectToDevice(device, btService);
  }

  void _startFreshScan() async {
    setState(() => _errorMessage = null);
    final granted = await _ensureBluetoothPermissions();
    if (!granted) return;
    ref.read(bluetoothDevicesProvider.notifier).startScan();
  }

  Future<void> _forgetAdapter() async {
    final vehicle = ref.read(activeVehicleProvider);
    if (vehicle == null) return;

    final repo = ref.read(vehicleRepositoryProvider);
    await repo.updateVehicle(vehicle.copyWith(clearObdAdapter: true));
  }

  /// Request Bluetooth + location runtime permissions (Android 12+).
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

      // Save adapter to Firestore on first successful connect
      await _saveAdapterToFirestore(device);

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

      // Auto-start recording to Firestore
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

  /// Save the adapter info to Firestore on the active vehicle doc.
  Future<void> _saveAdapterToFirestore(BluetoothDeviceInfo device) async {
    final vehicle = ref.read(activeVehicleProvider);
    if (vehicle == null) return;
    // Only save if not already saved (or address changed)
    if (vehicle.obdAdapter?.address == device.address) return;

    final adapter = ObdAdapter(
      name: device.name,
      address: device.address,
      type: device.isOBDLink ? 'OBDLink MX+' : 'ELM327',
      pairedAt: DateTime.now(),
    );

    final repo = ref.read(vehicleRepositoryProvider);
    await repo.updateVehicle(vehicle.copyWith(obdAdapter: adapter));
    diag.info('BT', 'Saved adapter to Firestore', '${adapter.name} (${adapter.address})');
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
