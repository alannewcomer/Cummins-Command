import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../config/maintenance_templates.dart';
import '../../../models/service_schedule.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../widgets/common/glass_card.dart';

class DashboardFeed extends ConsumerWidget {
  const DashboardFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(serviceSchedulesProvider);
    final checklistsAsync = ref.watch(checklistSessionsProvider);
    final seasonalAsync = ref.watch(seasonalTasksProvider);
    final vehicle = ref.watch(activeVehicleProvider);
    final odometer = vehicle?.currentOdometer ?? 0;
    final hours = vehicle?.currentEngineHours ?? 0;

    return schedulesAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (schedules) {
        final overdue = schedules
            .where((s) => s.isEnabled && s.isOverdue(odometer, currentHours: hours))
            .toList();
        final dueSoon = schedules
            .where((s) => s.isEnabled && s.isDueSoon(odometer, currentHours: hours))
            .toList();
        final activeSeasonalGroups = kSeasonalGroups
            .where((g) => g.isActive)
            .toList();

        final lastChecklist = checklistsAsync.value?.isNotEmpty == true
            ? checklistsAsync.value!.first
            : null;

        final completedSeasonalIds = (seasonalAsync.value ?? [])
            .map((t) => t.taskId)
            .toSet();

        return SliverList(
          delegate: SliverChildListDelegate([
            // Overdue items
            if (overdue.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text('Overdue',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.critical)),
              ),
              ...overdue.map((s) => _ScheduleActionCard(
                    schedule: s,
                    odometer: odometer,
                    engineHours: hours,
                    urgency: _Urgency.overdue,
                  )),
            ],
            // Due soon items
            if (dueSoon.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text('Due Soon',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.warning)),
              ),
              ...dueSoon.map((s) => _ScheduleActionCard(
                    schedule: s,
                    odometer: odometer,
                    engineHours: hours,
                    urgency: _Urgency.dueSoon,
                  )),
            ],
            // Seasonal nudges
            if (activeSeasonalGroups.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text('Seasonal Reminders',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.dataAccent)),
              ),
              ...activeSeasonalGroups.map((g) {
                final completed = g.tasks
                    .where((t) => completedSeasonalIds.contains(t.id))
                    .length;
                return _SeasonalNudgeCard(
                  group: g,
                  completedCount: completed,
                  onTap: () => ref
                      .read(maintenanceTabProvider.notifier)
                      .set(MaintenanceTab.seasonal),
                );
              }),
            ],
            // Last checklist status
            if (lastChecklist != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: _ChecklistStatusCard(
                  checklistTypeId: lastChecklist.checklistTypeId,
                  completedAt: lastChecklist.completedAt ?? lastChecklist.startedAt,
                  checkedCount: lastChecklist.checkedCount,
                  totalCount: lastChecklist.totalCount,
                  onTap: () => ref
                      .read(maintenanceTabProvider.notifier)
                      .set(MaintenanceTab.checklists),
                ),
              ),
            // Next Up — show upcoming services when nothing is overdue/due-soon
            if (overdue.isEmpty && dueSoon.isEmpty) ...[
              () {
                final upcoming = schedules
                    .where((s) => s.isEnabled &&
                        !s.isOverdue(odometer, currentHours: hours) &&
                        !s.isDueSoon(odometer, currentHours: hours))
                    .toList()
                  ..sort((a, b) =>
                      b.progressPercent(odometer, currentHours: hours)
                          .compareTo(a.progressPercent(odometer, currentHours: hours)));
                final top = upcoming.take(5).toList();
                if (top.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                      child: Text('Next Up',
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                    ...top.map((s) => _NextUpCard(
                          schedule: s,
                          odometer: odometer,
                          engineHours: hours,
                        )),
                  ],
                );
              }(),
            ],
            const SizedBox(height: AppSpacing.xxxl),
          ]),
        );
      },
    );
  }
}

enum _Urgency { overdue, dueSoon }

class _ScheduleActionCard extends StatelessWidget {
  final ServiceSchedule schedule;
  final double odometer;
  final double engineHours;
  final _Urgency urgency;

  const _ScheduleActionCard({
    required this.schedule,
    required this.odometer,
    required this.engineHours,
    required this.urgency,
  });

  @override
  Widget build(BuildContext context) {
    final color = urgency == _Urgency.overdue
        ? AppColors.critical
        : AppColors.warning;
    final template = getServiceType(schedule.serviceTypeId);
    final icon = template?.icon ?? Icons.build;
    final reason = schedule.urgencyReason(odometer, currentHours: engineHours);
    final trigger =
        schedule.leadingTrigger(odometer, currentHours: engineHours);
    final triggerIcon = switch (trigger) {
      UrgencyTrigger.miles => Icons.speed,
      UrgencyTrigger.time => Icons.calendar_month,
      UrgencyTrigger.hours => Icons.timer,
      UrgencyTrigger.none => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: GlassCard(
        borderColor: color.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule.name,
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.textPrimary)),
                  if (reason.isNotEmpty)
                    Row(
                      children: [
                        if (triggerIcon != null) ...[
                          Icon(triggerIcon, size: 12, color: color),
                          const SizedBox(width: 3),
                        ],
                        Text(reason,
                            style: AppTypography.bodySmall
                                .copyWith(color: color)),
                      ],
                    ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () => context.push('/maintenance/log-service',
                  extra: schedule.serviceTypeId),
              style: FilledButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.15),
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                textStyle: AppTypography.labelMedium,
              ),
              child: const Text('Log Service'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonalNudgeCard extends StatelessWidget {
  final SeasonalGroupTemplate group;
  final int completedCount;
  final VoidCallback onTap;

  const _SeasonalNudgeCard({
    required this.group,
    required this.completedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = group.tasks.length;
    final allDone = completedCount >= total;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(group.icon, size: 20, color: AppColors.dataAccent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.textPrimary)),
                  Text('$completedCount / $total tasks done',
                      style: AppTypography.bodySmall),
                ],
              ),
            ),
            if (allDone)
              Icon(Icons.check_circle, size: 20, color: AppColors.success)
            else
              Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  final ServiceSchedule schedule;
  final double odometer;
  final double engineHours;

  const _NextUpCard({
    required this.schedule,
    required this.odometer,
    required this.engineHours,
  });

  @override
  Widget build(BuildContext context) {
    final progress = schedule.progressPercent(odometer, currentHours: engineHours);
    final template = getServiceType(schedule.serviceTypeId);
    final icon = template?.icon ?? Icons.build;
    final trigger = schedule.leadingTrigger(odometer, currentHours: engineHours);

    // Build the "due at" text
    String dueText = '';
    switch (trigger) {
      case UrgencyTrigger.miles:
        final next = schedule.nextDueMiles(odometer);
        if (next != null) {
          final remaining = (next - odometer).round();
          dueText = '${NumberFormat('#,##0').format(remaining)} mi remaining';
        }
      case UrgencyTrigger.time:
        final next = schedule.nextDueDate;
        if (next != null) {
          final days = next.difference(DateTime.now()).inDays;
          dueText = days > 60
              ? '${(days / 30).round()} months remaining'
              : '$days days remaining';
        }
      case UrgencyTrigger.hours:
        final next = schedule.nextDueHours;
        if (next != null) {
          final remaining = (next - engineHours).round();
          dueText = '$remaining hrs remaining';
        }
      case UrgencyTrigger.none:
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule.name,
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.textPrimary)),
                  if (dueText.isNotEmpty)
                    Text(dueText, style: AppTypography.bodySmall),
                ],
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: AppTypography.dataSmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistStatusCard extends StatelessWidget {
  final String checklistTypeId;
  final DateTime completedAt;
  final int checkedCount;
  final int totalCount;
  final VoidCallback onTap;

  const _ChecklistStatusCard({
    required this.checklistTypeId,
    required this.completedAt,
    required this.checkedCount,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final template = getChecklist(checklistTypeId);
    final name = template?.name ?? checklistTypeId;
    final dateStr = DateFormat('MMM d').format(completedAt);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.checklist, size: 20, color: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last Checklist: $name',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.textPrimary)),
                Text('$dateStr — $checkedCount/$totalCount checked',
                    style: AppTypography.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
