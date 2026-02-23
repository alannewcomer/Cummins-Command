import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../models/drive_session.dart';
import '../../providers/drives_provider.dart';
import '../../providers/drive_stats_provider.dart';
import '../../widgets/ai/ai_progress_indicator.dart';
import '../../widgets/ai/ai_status_strip.dart';
import '../../widgets/common/glass_card.dart';
import 'sections/route_map_section.dart';
import 'sections/drive_overview_section.dart';
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
                    context.go('/explorer');
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

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 4. Mini Sparklines (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => SparklineSection(stats: stats),
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
              data: (stats) => EngineSection(stats: stats),
              loading: () => const _ShimmerSection(height: 200),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 7. Thermal Profile (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => ThermalSection(stats: stats),
              loading: () => const _ShimmerSection(height: 300),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 8. Drivetrain (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => DrivetrainSection(stats: stats),
              loading: () => const _ShimmerSection(height: 180),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 9. Emissions & DPF (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) =>
                  EmissionsSection(drive: drive, stats: stats),
              loading: () => const _ShimmerSection(height: 180),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 10. System Health (Tier 2) ───
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) => SystemSection(stats: stats),
              loading: () => const _ShimmerSection(height: 120),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

          // ─── 11. Tags (Tier 1) ───
          if (drive.tags.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _TagsSection(tags: drive.tags),
              ),
            ),

          // ─── 12. Open in Data Explorer ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _OpenInExplorerButton(
                onTap: () {
                  HapticFeedback.lightImpact();
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

// ─── Tags Section ───

class _TagsSection extends StatelessWidget {
  final List<String> tags;

  const _TagsSection({required this.tags});

  @override
  Widget build(BuildContext context) {
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
          children: tags.map((tag) {
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
          }).toList(),
        ),
      ],
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
