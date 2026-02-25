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

class ScheduleTab extends ConsumerWidget {
  const ScheduleTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(serviceSchedulesProvider);
    final vehicle = ref.watch(activeVehicleProvider);
    final odometer = vehicle?.currentOdometer ?? 0;
    final hours = vehicle?.currentEngineHours ?? 0;

    return schedulesAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (schedules) {
        final enabled = schedules.where((s) => s.isEnabled).toList();
        if (enabled.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_note_outlined,
                        size: 48, color: AppColors.textTertiary.withValues(alpha: 0.3)),
                    const SizedBox(height: AppSpacing.md),
                    Text('No schedules configured', style: AppTypography.displaySmall),
                  ],
                ),
              ),
            ),
          );
        }

        // Group by category
        final categories = <String, List<ServiceSchedule>>{};
        for (final s in enabled) {
          final template = getServiceType(s.serviceTypeId);
          final cat = template?.category ?? 'Other';
          categories.putIfAbsent(cat, () => []).add(s);
        }

        final widgets = <Widget>[
          // Odometer + hours display
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.speed, size: 16, color: AppColors.dataAccent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${NumberFormat('#,##0').format(odometer)} mi',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.dataAccent),
                ),
                if (hours > 0) ...[
                  const SizedBox(width: AppSpacing.lg),
                  Icon(Icons.timer_outlined, size: 16, color: AppColors.dataAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${NumberFormat('#,##0').format(hours)} hrs',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.dataAccent),
                  ),
                ],
              ],
            ),
          ),
        ];

        for (final entry in categories.entries) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Text(entry.key,
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.textSecondary)),
            ),
          );
          for (final s in entry.value) {
            widgets.add(_ServiceScheduleRow(
                schedule: s, odometer: odometer, engineHours: hours));
          }
        }
        widgets.add(const SizedBox(height: AppSpacing.xxxl));

        return SliverList(delegate: SliverChildListDelegate(widgets));
      },
    );
  }
}

class _ServiceScheduleRow extends StatefulWidget {
  final ServiceSchedule schedule;
  final double odometer;
  final double engineHours;

  const _ServiceScheduleRow({
    required this.schedule,
    required this.odometer,
    required this.engineHours,
  });

  @override
  State<_ServiceScheduleRow> createState() => _ServiceScheduleRowState();
}

class _ServiceScheduleRowState extends State<_ServiceScheduleRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final odometer = widget.odometer;
    final hours = widget.engineHours;
    final progress = s.progressPercent(odometer, currentHours: hours);
    final overdue = s.isOverdue(odometer, currentHours: hours);
    final dueSoon = s.isDueSoon(odometer, currentHours: hours);
    final trigger = s.leadingTrigger(odometer, currentHours: hours);
    final reason = s.urgencyReason(odometer, currentHours: hours);
    final template = getServiceType(s.serviceTypeId);
    final icon = template?.icon ?? Icons.build;

    final progressColor = overdue
        ? AppColors.critical
        : dueSoon
            ? AppColors.warning
            : AppColors.success;

    // Trigger icon for the leading urgency
    final triggerIcon = switch (trigger) {
      UrgencyTrigger.miles => Icons.speed,
      UrgencyTrigger.time => Icons.calendar_month,
      UrgencyTrigger.hours => Icons.timer,
      UrgencyTrigger.none => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: GlassCard(
        borderColor: overdue ? AppColors.critical.withValues(alpha: 0.3) : null,
        onTap: () => setState(() => _expanded = !_expanded),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: progressColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.textPrimary)),
                      if (reason.isNotEmpty)
                        Row(
                          children: [
                            if (triggerIcon != null) ...[
                              Icon(triggerIcon, size: 11, color: progressColor),
                              const SizedBox(width: 3),
                            ],
                            Text(reason,
                                style: AppTypography.bodySmall
                                    .copyWith(color: progressColor, fontSize: 11)),
                          ],
                        ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTypography.dataSmall.copyWith(color: progressColor),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceBorder,
                color: progressColor,
                minHeight: 6,
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: AppSpacing.md),
              // Interval row — show all active triggers
              _DetailRow(
                label: 'Interval',
                value: _intervalString(s),
              ),
              if (s.lastServiceMiles != null)
                _DetailRow(
                  label: 'Last Service',
                  value:
                      '${NumberFormat('#,##0').format(s.lastServiceMiles)} mi'
                      '${s.lastServiceDate != null ? ' (${DateFormat('MMM d, yyyy').format(s.lastServiceDate!)})' : ''}'
                      '${s.lastServiceHours != null ? ' @ ${NumberFormat('#,##0').format(s.lastServiceHours)} hrs' : ''}',
                ),
              // Per-trigger remaining breakdown
              ..._triggerDetails(s, odometer, hours),
              if (template?.notes != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(template!.notes!,
                      style: AppTypography.bodySmall
                          .copyWith(fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => context.push('/maintenance/log-service',
                      extra: s.serviceTypeId),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDim,
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    textStyle: AppTypography.labelMedium,
                  ),
                  child: const Text('Log Service'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _intervalString(ServiceSchedule s) {
    final parts = <String>[
      '${NumberFormat('#,##0').format(s.intervalMiles)} mi',
    ];
    if (s.intervalMonths != null) parts.add('${s.intervalMonths} mo');
    if (s.intervalHours != null) parts.add('${s.intervalHours} hrs');
    return parts.join(' / ');
  }

  /// Build per-trigger detail rows when expanded.
  List<Widget> _triggerDetails(
      ServiceSchedule s, double odometer, double hours) {
    final rows = <Widget>[];

    // Miles
    final nextMiles = s.nextDueMiles(odometer);
    if (nextMiles != null) {
      final diff = (nextMiles - odometer).round();
      rows.add(_TriggerRow(
        icon: Icons.speed,
        label: 'Miles',
        remaining: diff,
        suffix: 'mi',
      ));
    }

    // Time
    final nextDate = s.nextDueDate;
    if (nextDate != null) {
      final days = nextDate.difference(DateTime.now()).inDays;
      rows.add(_TriggerRow(
        icon: Icons.calendar_month,
        label: 'Time',
        remaining: days,
        suffix: 'days',
      ));
    }

    // Hours
    final nextHrs = s.nextDueHours;
    if (nextHrs != null && hours > 0) {
      final diff = (nextHrs - hours).round();
      rows.add(_TriggerRow(
        icon: Icons.timer,
        label: 'Hours',
        remaining: diff,
        suffix: 'hrs',
      ));
    }

    return rows;
  }
}

class _TriggerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int remaining;
  final String suffix;

  const _TriggerRow({
    required this.icon,
    required this.label,
    required this.remaining,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = remaining < 0;
    final color = overdue
        ? AppColors.critical
        : remaining < 500 && suffix == 'mi'
            ? AppColors.warning
            : remaining < 30 && suffix == 'days'
                ? AppColors.warning
                : remaining < 50 && suffix == 'hrs'
                    ? AppColors.warning
                    : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.bodySmall.copyWith(fontSize: 11)),
          const Spacer(),
          Text(
            overdue
                ? '${remaining.abs()} $suffix overdue'
                : '${remaining.abs()} $suffix remaining',
            style: AppTypography.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall),
          Flexible(
            child: Text(value,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
