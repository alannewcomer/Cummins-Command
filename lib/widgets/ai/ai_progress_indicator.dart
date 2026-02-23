import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Progress indicator for long-running AI jobs.
/// Shows current step and progress percentage with animated bar.
class AiProgressIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String? currentStep;
  final String status; // queued, processing, complete, failed

  const AiProgressIndicator({
    super.key,
    required this.progress,
    this.currentStep,
    this.status = 'processing',
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'complete';
    final isFailed = status == 'failed';
    final isQueued = status == 'queued';

    final color = isFailed
        ? AppColors.critical
        : isComplete
            ? AppColors.success
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(
                  isFailed
                      ? Icons.error_outline
                      : isComplete
                          ? Icons.check_circle_outline
                          : Icons.diamond_outlined,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isQueued
                          ? 'Queued'
                          : isFailed
                              ? 'Analysis Failed'
                              : isComplete
                                  ? 'Analysis Complete'
                                  : 'AI Analyzing...',
                      style: AppTypography.labelLarge.copyWith(color: color),
                    ),
                    if (currentStep != null)
                      Text(
                        currentStep!,
                        style: AppTypography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTypography.dataMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: AppColors.gaugeArc),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    widthFactor: progress.clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.6), color],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
