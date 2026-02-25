import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/drive_session.dart';
import '../../providers/drives_provider.dart';
import '../../widgets/cards/drive_card.dart';
import '../../widgets/common/glass_card.dart';

class DriveHistoryScreen extends ConsumerWidget {
  const DriveHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivesAsync = ref.watch(drivesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            title: Text('Drive History', style: AppTypography.displaySmall),
          ),

          // Summary card (total drive time + idle time)
          drivesAsync.when(
            data: (drives) {
              if (drives.isEmpty) return const SliverToBoxAdapter();
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: _TripSummaryCard(drives: drives),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(),
            error: (_, __) => const SliverToBoxAdapter(),
          ),

          // Drive list
          drivesAsync.when(
            data: (drives) {
              if (drives.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= drives.length) return null;
                      final drive = drives[index];
                      return _StaggeredDriveCard(
                        index: index,
                        drive: drive,
                        onTap: () => context.push('/drives/${drive.id}'),
                      );
                    },
                    childCount: drives.length,
                  ),
                ),
              );
            },
            loading: () => SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ShimmerDriveCard(index: index),
                  ),
                  childCount: 5,
                ),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(error: error.toString()),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }
}

// ─── Trip Summary Card ───

class _TripSummaryCard extends StatelessWidget {
  final List<DriveSession> drives;

  const _TripSummaryCard({required this.drives});

  @override
  Widget build(BuildContext context) {
    // Aggregate totals
    int totalDriveSeconds = 0;
    int totalIdleSeconds = 0;
    double totalDistance = 0;

    for (final d in drives) {
      totalDriveSeconds += d.durationSeconds;
      totalIdleSeconds += d.idleSeconds;
      totalDistance += d.distanceMiles;
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.local_shipping_outlined,
              label: 'DRIVES',
              value: '${drives.length}',
              color: AppColors.primary,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.timer_outlined,
              label: 'DRIVE TIME',
              value: _formatDuration(totalDriveSeconds),
              color: AppColors.dataAccent,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.pause_circle_outline,
              label: 'IDLE TIME',
              value: _formatDuration(totalIdleSeconds),
              color: totalIdleSeconds > 0
                  ? AppColors.warning
                  : AppColors.textTertiary,
            ),
          ),
          _divider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.straighten,
              label: 'DISTANCE',
              value: '${totalDistance.toStringAsFixed(0)} mi',
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.surfaceBorder,
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '--';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.dataMedium.copyWith(
            color: color,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontSize: 8,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

// ─── Staggered Drive Card with fade-in animation ───

class _StaggeredDriveCard extends StatefulWidget {
  final int index;
  final DriveSession drive;
  final VoidCallback onTap;

  const _StaggeredDriveCard({
    required this.index,
    required this.drive,
    required this.onTap,
  });

  @override
  State<_StaggeredDriveCard> createState() => _StaggeredDriveCardState();
}

class _StaggeredDriveCardState extends State<_StaggeredDriveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Stagger: 60ms per card, capped at 600ms
    final delay = (widget.index * 60).clamp(0, 600);
    Future.delayed(Duration(milliseconds: delay), () {
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
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DriveCard(
            drive: widget.drive,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Loading Card ───

class _ShimmerDriveCard extends StatefulWidget {
  final int index;
  const _ShimmerDriveCard({required this.index});

  @override
  State<_ShimmerDriveCard> createState() => _ShimmerDriveCardState();
}

class _ShimmerDriveCardState extends State<_ShimmerDriveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmer = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        return Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            gradient: LinearGradient(
              begin: Alignment(_shimmer.value - 1, 0),
              end: Alignment(_shimmer.value, 0),
              colors: const [
                AppColors.surface,
                AppColors.surfaceLight,
                AppColors.surface,
              ],
            ),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
        );
      },
    );
  }
}

// ─── Empty State ───

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'No Drives Yet',
              style: AppTypography.displaySmall.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start recording drives to build your\nhistory and unlock AI insights.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            GestureDetector(
              onTap: () => context.push('/bluetooth-setup'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        size: 14, color: Colors.white),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Start Recording',
                      style: AppTypography.button,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error State ───

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.critical),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Error Loading Drives',
              style: AppTypography.displaySmall.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
