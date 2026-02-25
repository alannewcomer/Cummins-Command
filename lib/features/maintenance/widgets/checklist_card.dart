import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../config/maintenance_templates.dart';
import '../../../models/checklist_session.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../widgets/common/glass_card.dart';

class ChecklistsTab extends ConsumerWidget {
  const ChecklistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(checklistSessionsProvider);

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: AppSpacing.lg),
        ...kChecklists.map((template) {
          // Find most recent active (incomplete) session for this checklist
          final activeSession = sessionsAsync.value
              ?.where((s) =>
                  s.checklistTypeId == template.id && s.completedAt == null)
              .toList();
          final session =
              activeSession != null && activeSession.isNotEmpty
                  ? activeSession.first
                  : null;

          return _ChecklistGroup(
            key: ValueKey(template.id),
            template: template,
            activeSession: session,
          );
        }),
        const SizedBox(height: AppSpacing.xxxl),
      ]),
    );
  }
}

class _ChecklistGroup extends ConsumerStatefulWidget {
  final ChecklistTemplate template;
  final ChecklistSession? activeSession;

  const _ChecklistGroup({super.key, required this.template, this.activeSession});

  @override
  ConsumerState<_ChecklistGroup> createState() => _ChecklistGroupState();
}

class _ChecklistGroupState extends ConsumerState<_ChecklistGroup> {
  bool _expanded = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.activeSession != null;
  }

  @override
  void didUpdateWidget(covariant _ChecklistGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-expand when a session becomes available (user tapped "Start")
    if (oldWidget.activeSession == null && widget.activeSession != null) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final session = widget.activeSession;
    final checkedCount = session?.checkedCount ?? 0;
    final totalCount = template.items.length;
    final isComplete = session?.isComplete ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: GlassCard(
        borderColor: isComplete ? AppColors.success.withValues(alpha: 0.3) : null,
        glowColor: isComplete ? AppColors.success : null,
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
                    Icon(template.icon, size: 20, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(template.name,
                              style: AppTypography.labelLarge
                                  .copyWith(color: AppColors.textPrimary)),
                          Text(template.description,
                              style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    if (session != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isComplete
                              ? AppColors.successDim
                              : AppColors.warningDim,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          isComplete
                              ? 'Complete'
                              : '$checkedCount/$totalCount',
                          style: AppTypography.labelSmall.copyWith(
                            color: isComplete
                                ? AppColors.success
                                : AppColors.warning,
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
            // Expanded content
            if (_expanded) ...[
              const Divider(height: 1),
              if (session == null)
                // Start new session
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _starting ? null : () => _startChecklist(ref, template),
                      icon: _starting
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow, size: 18),
                      label: Text(_starting ? 'Starting...' : 'Start Checklist'),
                    ),
                  ),
                )
              else ...[
                // Checklist items
                ...template.items.map((item) {
                  final checked = session.itemStates[item.id] ?? false;
                  return _ChecklistItemRow(
                    item: item,
                    checked: checked,
                    onChanged: (val) {
                      ref.read(maintenanceRepositoryProvider)
                          .updateChecklistItem(session.id, item.id, val);
                    },
                  );
                }),
                // Complete All / Finish buttons
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _completeAll(ref, session, template),
                          child: const Text('Check All'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isComplete
                              ? () => _finishChecklist(ref, session)
                              : null,
                          child: const Text('Complete'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startChecklist(WidgetRef ref, ChecklistTemplate template) async {
    setState(() => _starting = true);
    try {
      final vehicle = ref.read(activeVehicleProvider);
      if (vehicle == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No vehicle selected. Please set up your vehicle first.')),
          );
        }
        return;
      }
      final sessionId = await ref.read(maintenanceRepositoryProvider).startChecklist(
        checklistTypeId: template.id,
        itemIds: template.items.map((i) => i.id).toList(),
        odometerReading: vehicle.currentOdometer,
      );
      if (sessionId == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start checklist. Please try again.')),
        );
        return;
      }
      // The stream will rebuild with the new session, and didUpdateWidget
      // will auto-expand. But if that doesn't fire fast enough, force expand.
      if (sessionId != null && mounted) {
        setState(() => _expanded = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting checklist: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _completeAll(
      WidgetRef ref, ChecklistSession session, ChecklistTemplate template) async {
    final repo = ref.read(maintenanceRepositoryProvider);
    for (final item in template.items) {
      if (!(session.itemStates[item.id] ?? false)) {
        await repo.updateChecklistItem(session.id, item.id, true);
      }
    }
  }

  Future<void> _finishChecklist(WidgetRef ref, ChecklistSession session) async {
    await ref.read(maintenanceRepositoryProvider).completeChecklist(session.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist completed!')),
      );
    }
  }
}

class _ChecklistItemRow extends StatelessWidget {
  final ChecklistItemTemplate item;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _ChecklistItemRow({
    required this.item,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: checked,
                onChanged: (val) => onChanged(val ?? false),
                activeColor: AppColors.success,
                side: const BorderSide(color: AppColors.surfaceBorder, width: 2),
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
                    item.label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: checked
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.tip != null)
                    Text(item.tip!,
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
