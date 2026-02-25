import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../app/theme.dart';
import '../../config/constants.dart';
import '../../models/drive_session.dart';
import '../../providers/data_explorer_provider.dart';
import '../../providers/drives_provider.dart';
import '../../providers/drive_stats_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/ai/ai_progress_indicator.dart';
import '../../widgets/ai/ai_status_strip.dart';
import '../../widgets/common/glass_card.dart';
import 'sections/route_map_section.dart';
import 'sections/drive_overview_section.dart';
import 'sections/notes_section.dart';
import 'sections/photos_section.dart';
import 'sections/sparkline_section.dart';
import 'sections/engine_section.dart';
import 'sections/thermal_section.dart';
import 'sections/drivetrain_section.dart';
import 'sections/emissions_section.dart';
import 'sections/system_section.dart';

class DriveDetailScreen extends ConsumerWidget {
  final String driveId;

  const DriveDetailScreen({super.key, required this.driveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driveAsync = ref.watch(driveDetailProvider(driveId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: driveAsync.when(
        data: (drive) {
          if (drive == null) {
            return const _NotFoundState();
          }
          return _DriveDetailBody(drive: drive, driveId: driveId);
        },
        loading: () => const _LoadingState(),
        error: (error, _) => _ErrorState(error: error.toString()),
      ),
    );
  }
}

class _DriveDetailBody extends ConsumerStatefulWidget {
  final DriveSession drive;
  final String driveId;

  const _DriveDetailBody({required this.drive, required this.driveId});

  @override
  ConsumerState<_DriveDetailBody> createState() => _DriveDetailBodyState();
}

class _DriveDetailBodyState extends ConsumerState<_DriveDetailBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Navigate to Data Explorer with a specific parameter pre-selected,
  /// scoped to this drive's time range.
  void _openInExplorer(String paramId) {
    HapticFeedback.lightImpact();
    final drive = widget.drive;
    ref.read(selectedParamsProvider.notifier).setParams([paramId]);
    // Scope to this drive's time range
    if (drive.endTime != null) {
      ref.read(timeRangeProvider.notifier).setCustomRange(
        drive.startTime,
        drive.endTime!,
      );
    }
    context.go('/explorer');
  }

  @override
  Widget build(BuildContext context) {
    final drive = widget.drive;
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final healthScore = drive.aiHealthScore;
    final healthColor = _healthColor(healthScore);

    // Tier 2 data: DriveStats from datapoints
    final statsAsync = ref.watch(driveStatsProvider(widget.driveId));

    return FadeTransition(
      opacity: _fadeAnim,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── AppBar ───
          SliverAppBar(
            floating: false,
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: const Icon(Icons.arrow_back, size: 18),
              ),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(drive.startTime),
                  style: AppTypography.displaySmall.copyWith(fontSize: 14),
                ),
                Text(
                  '${timeFormat.format(drive.startTime)}${drive.endTime != null ? ' - ${timeFormat.format(drive.endTime!)}' : ' - In Progress'}',
                  style: AppTypography.labelSmall,
                ),
              ],
            ),
            actions: [
              if (drive.hasAiAnalysis)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AiBadge(model: 'GEMINI 3.1 PRO'),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  side: const BorderSide(color: AppColors.surfaceBorder),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'explorer',
                    child: Row(
                      children: [
                        Icon(Icons.insights, size: 18, color: AppColors.dataAccent),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Open in Explorer', style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Share Drive', style: AppTypography.bodyMedium),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'explorer') {
                    // Scope explorer to this drive's time range
                    if (drive.endTime != null) {
                      ref.read(timeRangeProvider.notifier).setCustomRange(
                        drive.startTime,
                        drive.endTime!,
                      );
                    }
                    context.go('/explorer');
                  } else if (value == 'share') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share coming soon')),
                    );
                  }
                },
              ),
            ],
          ),

          // ─── 1. Health Score Hero (Tier 1 — instant) ───
          SliverToBoxAdapter(
            child: _HealthScoreHero(
              score: healthScore,
              color: healthColor,
              status: drive.status,
            ),
          ),

          // ─── 1b. Route Badge ───
          if (drive.routeId != null && drive.routeName != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.md,
                ),
                child: _RouteBadge(
                  routeName: drive.routeName!,
                  routeId: drive.routeId!,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 2. Route Map (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => RouteMapSection(stats: stats),
              loading: () => const _ShimmerSection(height: 120),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 3. Drive Overview (Tier 2 for idle%, avg speed) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) =>
                  DriveOverviewSection(drive: drive, stats: stats),
              loading: () => const _ShimmerSection(height: 160),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // ─── View All Stats button ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _ViewAllStatsButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/drives/${widget.driveId}/stats');
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 3b. Notes & Cargo ───
          SliverToBoxAdapter(
            child: NotesSection(drive: drive),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 3c. Photos ───
          SliverToBoxAdapter(
            child: PhotosSection(drive: drive),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 4. Mini Sparklines (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => SparklineSection(
                stats: stats,
                onParamTap: _openInExplorer,
              ),
              loading: () => const _ShimmerSection(height: 280),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 5. AI Analysis (Tier 1 — instant) ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _AiAnalysisSection(drive: drive),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 6. Engine Performance (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => EngineSection(
                stats: stats,
                onParamTap: _openInExplorer,
              ),
              loading: () => const _ShimmerSection(height: 200),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 7. Thermal Profile (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => ThermalSection(
                stats: stats,
                onParamTap: _openInExplorer,
              ),
              loading: () => const _ShimmerSection(height: 300),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 8. Drivetrain (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => DrivetrainSection(
                stats: stats,
                onParamTap: _openInExplorer,
              ),
              loading: () => const _ShimmerSection(height: 180),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 9. Emissions & DPF (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => EmissionsSection(
                drive: drive,
                stats: stats,
                onParamTap: _openInExplorer,
              ),
              loading: () => const _ShimmerSection(height: 180),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 10. System Health (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => SystemSection(
                stats: stats,
                onParamTap: _openInExplorer,
              ),
              loading: () => const _ShimmerSection(height: 120),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 11. Tags (Tier 1) ───
          if (drive.tags.isNotEmpty || drive.autoTags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _TagsSection(
                  tags: drive.tags,
                  autoTags: drive.autoTags,
                  driveId: drive.id,
                ),
              ),
            ),

          // ─── 12. Open in Data Explorer ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _OpenInExplorerButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Scope explorer to this drive's time range
                  if (drive.endTime != null) {
                    ref.read(timeRangeProvider.notifier).setCustomRange(
                      drive.startTime,
                      drive.endTime!,
                    );
                  }
                  context.go('/explorer');
                },
              ),
            ),
          ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + AppSpacing.xxxl,
            ),
          ),
        ],
      ),
    );
  }

  Color _healthColor(int? score) {
    if (score == null) return AppColors.textTertiary;
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.critical;
  }
}

// ─── Shimmer section placeholder ───

class _ShimmerSection extends StatelessWidget {
  final double height;

  const _ShimmerSection({required this.height});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ShimmerCard(height: height),
    );
  }
}

// ─── Health Score Hero ───

class _HealthScoreHero extends StatefulWidget {
  final int? score;
  final Color color;
  final DriveStatus status;

  const _HealthScoreHero({
    required this.score,
    required this.color,
    required this.status,
  });

  @override
  State<_HealthScoreHero> createState() => _HealthScoreHeroState();
}

class _HealthScoreHeroState extends State<_HealthScoreHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: (widget.score ?? 0) / 100.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    Future.delayed(const Duration(milliseconds: 300), () {
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
    if (widget.score == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.status == DriveStatus.pendingAnalysis
                    ? Icons.hourglass_top
                    : Icons.analytics_outlined,
                color: AppColors.textTertiary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.status == DriveStatus.pendingAnalysis
                    ? 'AI analysis pending...'
                    : 'Health score not yet available',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: AnimatedBuilder(
          animation: _progressAnim,
          builder: (context, child) {
            final displayScore =
                (_progressAnim.value * 100).clamp(0, widget.score!).toInt();
            return Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Animated ring
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: _progressAnim.value,
                            strokeWidth: 6,
                            backgroundColor: AppColors.gaugeArc,
                            valueColor:
                                AlwaysStoppedAnimation(widget.color),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displayScore',
                              style: AppTypography.dataLarge.copyWith(
                                color: widget.color,
                              ),
                            ),
                            Text(
                              'HEALTH',
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 7,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  // Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _healthLabel(widget.score!),
                          style: AppTypography.displaySmall.copyWith(
                            color: widget.color,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _healthDescription(widget.score!),
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _healthLabel(int score) {
    if (score >= 90) return 'Excellent Drive';
    if (score >= 80) return 'Great Drive';
    if (score >= 70) return 'Good Drive';
    if (score >= 60) return 'Fair Drive';
    return 'Needs Review';
  }

  String _healthDescription(int score) {
    if (score >= 90) {
      return 'All parameters stayed within optimal ranges throughout this drive.';
    }
    if (score >= 80) {
      return 'Most parameters were in excellent condition with minor deviations.';
    }
    if (score >= 70) {
      return 'Good overall performance. Some parameters could be optimized.';
    }
    if (score >= 60) {
      return 'Some parameters exceeded recommended thresholds. Review AI analysis.';
    }
    return 'Multiple parameters exceeded safe thresholds. Immediate review recommended.';
  }
}

// ─── AI Analysis Section ───

class _AiAnalysisSection extends StatelessWidget {
  final DriveSession drive;

  const _AiAnalysisSection({required this.drive});

  @override
  Widget build(BuildContext context) {
    // Show progress indicator for pending analysis
    if (drive.status == DriveStatus.pendingAnalysis) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.diamond_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'AI Analysis',
                style: AppTypography.displaySmall.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const AiProgressIndicator(
            progress: 0.35,
            currentStep: 'Analyzing engine parameters...',
            status: 'processing',
          ),
        ],
      );
    }

    // No analysis available
    if (!drive.hasAiAnalysis || drive.aiSummary == null) {
      return const SizedBox.shrink();
    }

    // Full analysis display
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.diamond_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'AI Analysis',
              style: AppTypography.displaySmall.copyWith(fontSize: 14),
            ),
            const Spacer(),
            AiBadge(model: 'GEMINI 3.1 PRO'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Summary
        GlassCard(
          glowColor: AppColors.primary,
          borderColor: AppColors.primary.withValues(alpha: 0.2),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Summary',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                drive.aiSummary!,
                style: AppTypography.aiText.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),

        // Anomalies
        if (drive.aiAnomalies.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            borderColor: AppColors.warning.withValues(alpha: 0.2),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Anomalies Detected',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningDim,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        '${drive.aiAnomalies.length}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ...drive.aiAnomalies.map((anomaly) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              anomaly,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],

        // Recommendations
        if (drive.aiRecommendations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            borderColor: AppColors.success.withValues(alpha: 0.2),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Recommendations',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ...drive.aiRecommendations.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withValues(alpha: 0.12),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Route Badge ───

class _RouteBadge extends StatelessWidget {
  final String routeName;
  final String routeId;

  const _RouteBadge({required this.routeName, required this.routeId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/routes/$routeId');
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryDim,
              borderRadius: BorderRadius.circular(AppRadius.round),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place, size: 14, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  routeName,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right,
                    size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tags Section ───

class _TagsSection extends ConsumerWidget {
  final List<String> tags;
  final List<String> autoTags;
  final String driveId;

  const _TagsSection({
    required this.tags,
    required this.autoTags,
    required this.driveId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: AppTypography.displaySmall.copyWith(fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            // AI auto-tags
            ...autoTags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryDim,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.diamond_outlined,
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      tag,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
            // User tags
            ...tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dataAccentDim,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                    color: AppColors.dataAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  tag,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.dataAccent,
                  ),
                ),
              );
            }),
            // Add tag button
            GestureDetector(
              onTap: () => _showAddTagSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddTagSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    const suggestions = [
      'Towing', 'Commute', 'Road Trip', 'Mountain', 'City',
      'Highway', 'Track', 'Empty', 'Loaded',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xxl,
            right: AppSpacing.xxl,
            top: AppSpacing.xxl,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text('Add Tag', style: AppTypography.displaySmall),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Custom tag...',
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _addTag(ref, value.trim());
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Suggestions', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: suggestions
                    .where((s) => !tags.contains(s))
                    .map((s) {
                  return GestureDetector(
                    onTap: () {
                      _addTag(ref, s);
                      Navigator.pop(ctx);
                    },
                    child: Chip(
                      label: Text(s),
                      backgroundColor: AppColors.surfaceLight,
                      side: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addTag(WidgetRef ref, String tag) {
    final uid = ref.read(userIdProvider);
    final vehicle = ref.read(activeVehicleProvider);
    if (uid == null || vehicle == null) return;

    FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(vehicle.id)
        .collection(AppConstants.drivesSubcollection)
        .doc(driveId)
        .update({
      'tags': FieldValue.arrayUnion([tag]),
    });
  }
}

// ─── View All Stats Button ───

class _ViewAllStatsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewAllStatsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'View All Stats',
              style: AppTypography.button.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.arrow_forward,
              color: AppColors.primary.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Open in Data Explorer Button ───

class _OpenInExplorerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OpenInExplorerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.dataAccent.withValues(alpha: 0.12),
              AppColors.dataAccent.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: AppColors.dataAccent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights,
              color: AppColors.dataAccent,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Open in Data Explorer',
              style: AppTypography.button.copyWith(
                color: AppColors.dataAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.arrow_forward,
              color: AppColors.dataAccent.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading / Error / Not Found States ───

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Loading drive...', style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}

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
              'Error Loading Drive',
              style: AppTypography.displaySmall.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Drive Not Found',
              style: AppTypography.displaySmall.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This drive may have been deleted\nor is no longer available.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
