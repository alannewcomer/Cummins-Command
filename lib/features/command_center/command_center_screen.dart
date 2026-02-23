import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/dashboard_config.dart';
import '../../providers/ai_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/drives_provider.dart';
import '../../providers/live_data_provider.dart';
import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/ai/ai_status_strip.dart';
import '../../widgets/cards/stat_card.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/dashboard_widgets/dashboard_widget_factory.dart';

class CommandCenterScreen extends ConsumerWidget {
  const CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isBluetoothConnectedProvider);
    final vehicle = ref.watch(activeVehicleProvider);
    final aiMessage = ref.watch(aiStatusMessageProvider);
    final isRecording = ref.watch(isRecordingProvider);
    final dashboardConfig = ref.watch(activeDashboardProvider);

    // Activate sparkline feeder and OBD lifecycle manager
    ref.watch(sparklineFeederProvider);
    ref.watch(obdLifecycleProvider);

    // Only show real live data — empty when disconnected
    final liveData = isConnected
        ? ref.watch(liveDataProvider)
        : <String, double>{};
    final sparklineData = isConnected
        ? ref.watch(sparklineDataProvider)
        : <String, List<double>>{};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar with vehicle name
          _CommandCenterAppBar(vehicle: vehicle),

          // AI Status Strip
          SliverToBoxAdapter(
            child: AiStatusStrip(
              message: isConnected
                  ? aiMessage
                  : 'Connect OBD adapter to enable live AI intelligence',
              isLoading: isConnected && aiMessage.isEmpty,
              onTap: () => context.go('/ai'),
            ),
          ),

          // Connect prompt when disconnected
          if (!isConnected)
            SliverToBoxAdapter(
              child: _ConnectObdCard(
                onConnect: () => context.push('/bluetooth-setup'),
              ),
            ),

          // Dashboard Grid — shows real data or empty gauges
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            sliver: _DashboardGrid(
              // Key forces full rebuild (with entrance animations) on switch
              key: ValueKey(dashboardConfig['name'] as String? ?? ''),
              dashboardConfig: dashboardConfig,
              liveData: liveData,
              sparklineData: sparklineData,
              isConnected: isConnected,
            ),
          ),

          // Bottom spacer for stats bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),

      // Bottom Stats Bar
      bottomNavigationBar: _StatsBar(
        isRecording: isRecording,
        isConnected: isConnected,
        liveData: liveData,
        onSwitchDashboard: () => _showDashboardSwitcher(context, ref),
        onExploreTap: () => context.push('/explorer'),
      ),
    );
  }

  void _showDashboardSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final templates = ref.watch(dashboardTemplatesProvider);
          final currentIndex = ref.watch(activeDashboardIndexProvider);

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollController) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Switch Dashboard',
                        style: AppTypography.displaySmall),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: templates.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final t = templates[index];
                          final isActive = index == currentIndex;
                          final name = t['name'] as String? ?? '';
                          final desc = t['description'] as String? ?? '';
                          final iconName = t['icon'] as String? ?? '';

                          return AnimatedContainer(
                            duration: AppTheme.animDuration,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.surfaceLight,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.medium),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : AppColors.surfaceBorder,
                                width: isActive ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                _templateIcon(iconName),
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              title: Text(
                                name,
                                style: AppTypography.labelLarge.copyWith(
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                desc,
                                style: AppTypography.bodySmall,
                              ),
                              trailing: isActive
                                  ? Icon(Icons.check_circle,
                                      color: AppColors.primary, size: 20)
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.medium),
                              ),
                              onTap: () {
                                ref
                                    .read(activeDashboardIndexProvider.notifier)
                                    .setIndex(index);
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom +
                            AppSpacing.lg),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static IconData _templateIcon(String name) {
    const map = {
      'directions_car': Icons.directions_car_outlined,
      'rv_hookup': Icons.rv_hookup_outlined,
      'terrain': Icons.terrain_outlined,
      'speed': Icons.speed_outlined,
      'eco': Icons.eco_outlined,
      'ac_unit': Icons.ac_unit_outlined,
      'new_releases': Icons.new_releases_outlined,
      'filter_alt': Icons.filter_alt_outlined,
      'list_alt': Icons.list_alt_outlined,
    };
    return map[name] ?? Icons.dashboard_outlined;
  }
}

// ─── AppBar ───

class _CommandCenterAppBar extends StatelessWidget {
  final Vehicle? vehicle;

  const _CommandCenterAppBar({this.vehicle});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      title: GestureDetector(
        onTap: () => context.go('/settings'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cummins icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Center(
                child: Text(
                  'C',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vehicle?.displayName ?? 'Cummins Command',
                    style: AppTypography.displaySmall.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    vehicle?.engine ?? '',
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
      actions: [
        // Connection indicator
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Consumer(
            builder: (context, ref, _) {
              final connected = ref.watch(isBluetoothConnectedProvider);
              return GestureDetector(
                onTap: () => context.push('/bluetooth-setup'),
                child: AnimatedContainer(
                  duration: AppTheme.animDuration,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: connected
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.round),
                    border: Border.all(
                      color: connected
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 14,
                        color: connected
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        connected ? 'LIVE' : 'OBD',
                        style: AppTypography.labelSmall.copyWith(
                          color: connected
                              ? AppColors.success
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Connect OBD Card ───

class _ConnectObdCard extends StatefulWidget {
  final VoidCallback onConnect;

  const _ConnectObdCard({required this.onConnect});

  @override
  State<_ConnectObdCard> createState() => _ConnectObdCardState();
}

class _ConnectObdCardState extends State<_ConnectObdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: GlassCard(
        glowColor: AppColors.dataAccent,
        borderColor: AppColors.dataAccent.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        onTap: widget.onConnect,
        child: Column(
          children: [
            // Pulsing Bluetooth icon
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.dataAccent
                        .withValues(alpha: 0.08 * _pulseAnim.value),
                    border: Border.all(
                      color: AppColors.dataAccent
                          .withValues(alpha: 0.25 * _pulseAnim.value),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.dataAccent
                            .withValues(alpha: 0.15 * _pulseAnim.value),
                        blurRadius: 24 * _pulseAnim.value,
                        spreadRadius: 4 * _pulseAnim.value,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.bluetooth,
                    size: 32,
                    color: AppColors.dataAccent
                        .withValues(alpha: 0.5 + 0.5 * _pulseAnim.value),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Connect OBD Adapter',
              style: AppTypography.displaySmall.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pair your OBDLink MX+ to unlock real-time\nengine monitoring and AI insights',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxl,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.dataAccent,
                    AppColors.dataAccent.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.round),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dataAccent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bluetooth_searching, size: 18, color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Scan for Devices',
                    style: AppTypography.button,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Grid ───

class _DashboardGrid extends StatelessWidget {
  final Map<String, dynamic> dashboardConfig;
  final Map<String, double> liveData;
  final Map<String, List<double>> sparklineData;
  final bool isConnected;

  const _DashboardGrid({
    super.key,
    required this.dashboardConfig,
    required this.liveData,
    required this.sparklineData,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final layoutMap =
        dashboardConfig['layout'] as Map<String, dynamic>? ?? {};
    final layout = DashboardLayout.fromMap(layoutMap);
    final columns = layout.columns;
    final widgets = layout.widgets;

    if (widgets.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              children: [
                Icon(
                  Icons.dashboard_customize_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No widgets configured',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // childAspectRatio can be overridden per-template (e.g., All Parameters)
    final aspectRatio =
        (layoutMap['childAspectRatio'] as num?)?.toDouble() ?? 1.0;

    // Build a flat list of widget configs, then display in a grid
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= widgets.length) return null;

          final widgetConfig = widgets[index];
          return _AnimatedDashboardWidget(
            index: index,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: DashboardWidgetFactory.build(
                  config: widgetConfig.toMap(),
                  liveData: liveData,
                  sparklineData: sparklineData,
                  onWidgetTap: (paramId) {
                    HapticFeedback.lightImpact();
                    context.push('/explorer');
                  },
                ),
              ),
            ),
          );
        },
        childCount: widgets.length,
      ),
    );
  }
}

class _AnimatedDashboardWidget extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedDashboardWidget({
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedDashboardWidget> createState() =>
      _AnimatedDashboardWidgetState();
}

class _AnimatedDashboardWidgetState extends State<_AnimatedDashboardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Stagger the animations
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

// ─── Stats Bar ───

class _StatsBar extends StatelessWidget {
  final bool isRecording;
  final bool isConnected;
  final Map<String, double> liveData;
  final VoidCallback onSwitchDashboard;
  final VoidCallback onExploreTap;

  const _StatsBar({
    required this.isRecording,
    required this.isConnected,
    required this.liveData,
    required this.onSwitchDashboard,
    required this.onExploreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Recording status indicator (auto-records when connected)
          _RecordingIndicator(
            isRecording: isRecording,
            isConnected: isConnected,
          ),
          QuickActionButton(
            icon: Icons.dashboard_customize_outlined,
            label: 'Dashboard',
            onTap: onSwitchDashboard,
          ),
          QuickActionButton(
            icon: Icons.insights_outlined,
            label: 'Explorer',
            color: AppColors.dataAccent,
            onTap: onExploreTap, // uses push — keeps CommandCenterScreen alive
          ),
        ],
      ),
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  final bool isRecording;
  final bool isConnected;

  const _RecordingIndicator({
    required this.isRecording,
    required this.isConnected,
  });

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isRecording) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_RecordingIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isRecording && old.isRecording) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.round),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              'Idle',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final glow = widget.isRecording ? _pulse.value : 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.critical.withValues(alpha: 0.1 + 0.05 * glow),
            borderRadius: BorderRadius.circular(AppRadius.round),
            border: Border.all(
              color: AppColors.critical.withValues(alpha: 0.4 + 0.2 * glow),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fiber_manual_record,
                size: 10,
                color: AppColors.critical.withValues(alpha: 0.6 + 0.4 * glow),
              ),
              const SizedBox(width: 6),
              Text(
                'REC',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.critical,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
