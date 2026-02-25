import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../config/maintenance_templates.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../widgets/common/glass_card.dart';

class SeasonalTab extends ConsumerWidget {
  const SeasonalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonalAsync = ref.watch(seasonalTasksProvider);
    final completedIds = (seasonalAsync.value ?? [])
        .map((t) => '${t.seasonalGroupId}_${t.taskId}')
        .toSet();

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: AppSpacing.lg),
        ...kSeasonalGroups.map((group) => _SeasonalGroupCard(
              group: group,
              completedIds: completedIds,
            )),
        const SizedBox(height: AppSpacing.xxxl),
      ]),
    );
  }
}

class _SeasonalGroupCard extends ConsumerStatefulWidget {
  final SeasonalGroupTemplate group;
  final Set<String> completedIds;

  const _SeasonalGroupCard({
    required this.group,
    required this.completedIds,
  });

  @override
  ConsumerState<_SeasonalGroupCard> createState() =>
      _SeasonalGroupCardState();
}

class _SeasonalGroupCardState extends ConsumerState<_SeasonalGroupCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Auto-expand if this season is active
    _expanded = widget.group.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final completedCount = group.tasks
        .where((t) => widget.completedIds.contains('${group.id}_${t.id}'))
        .length;
    final allDone = completedCount >= group.tasks.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: GlassCard(
        borderColor: group.isActive
            ? AppColors.dataAccent.withValues(alpha: 0.2)
            : null,
        glowColor: allDone ? AppColors.success : null,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(group.icon, size: 20, color: AppColors.dataAccent),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(group.name,
                                  style: AppTypography.labelLarge
                                      .copyWith(color: AppColors.textPrimary)),
                              if (group.isActive) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.dataAccentDim,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.small),
                                  ),
                                  child: Text('Active',
                                      style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.dataAccent,
                                          fontSize: 9)),
                                ),
                              ],
                            ],
                          ),
                          Text(group.season, style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: allDone
                            ? AppColors.successDim
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        '$completedCount/${group.tasks.length}',
                        style: AppTypography.labelSmall.copyWith(
                          color: allDone
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              ...group.tasks.map((task) {
                final done =
                    widget.completedIds.contains('${group.id}_${task.id}');
                return _SeasonalTaskRow(
                  task: task,
                  groupId: group.id,
                  season: group.season,
                  done: done,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeasonalTaskRow extends ConsumerWidget {
  final SeasonalTaskTemplate task;
  final String groupId;
  final String season;
  final bool done;

  const _SeasonalTaskRow({
    required this.task,
    required this.groupId,
    required this.season,
    required this.done,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        final repo = ref.read(maintenanceRepositoryProvider);
        if (done) {
          repo.unmarkSeasonalTask(
              seasonalGroupId: groupId, taskId: task.id);
        } else {
          repo.markSeasonalTaskDone(
            seasonalGroupId: groupId,
            taskId: task.id,
            season: season,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: done,
                onChanged: (_) {
                  final repo = ref.read(maintenanceRepositoryProvider);
                  if (done) {
                    repo.unmarkSeasonalTask(
                        seasonalGroupId: groupId, taskId: task.id);
                  } else {
                    repo.markSeasonalTaskDone(
                      seasonalGroupId: groupId,
                      taskId: task.id,
                      season: season,
                    );
                  }
                },
                activeColor: AppColors.success,
                side: const BorderSide(
                    color: AppColors.surfaceBorder, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: done
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (task.tip != null)
                    Text(task.tip!,
                        style: AppTypography.bodySmall
                            .copyWith(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
