import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../widgets/common/glass_card.dart';

class UrgencyHeroCard extends ConsumerWidget {
  const UrgencyHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgency = ref.watch(maintenanceUrgencyProvider);

    return GlassCard(
      glowColor: urgency.overdueCount > 0
          ? AppColors.critical
          : urgency.dueSoonCount > 0
              ? AppColors.warning
              : AppColors.success,
      borderColor: urgency.overdueCount > 0
          ? AppColors.critical.withValues(alpha: 0.4)
          : urgency.dueSoonCount > 0
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.surfaceBorder,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          _StatChip(
            label: 'OVERDUE',
            value: urgency.overdueCount.toString(),
            color: urgency.overdueCount > 0
                ? AppColors.critical
                : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.lg),
          _StatChip(
            label: 'DUE SOON',
            value: urgency.dueSoonCount.toString(),
            color: urgency.dueSoonCount > 0
                ? AppColors.warning
                : AppColors.textTertiary,
          ),
          const Spacer(),
          _StatChip(
            label: 'YTD COST',
            value: '\$${urgency.ytdCost.toStringAsFixed(0)}',
            color: AppColors.dataAccent,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.dataMedium.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
