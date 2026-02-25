import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../providers/maintenance_provider.dart';

class TabChipRow extends ConsumerWidget {
  const TabChipRow({super.key});

  static const _tabs = [
    (MaintenanceTab.dashboard, 'Dashboard', Icons.dashboard_outlined),
    (MaintenanceTab.schedule, 'Schedule', Icons.event_note_outlined),
    (MaintenanceTab.checklists, 'Checklists', Icons.checklist_outlined),
    (MaintenanceTab.seasonal, 'Seasonal', Icons.nature_outlined),
    (MaintenanceTab.history, 'History', Icons.history_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(maintenanceTabProvider);

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final (tab, label, icon) = _tabs[index];
          final selected = tab == current;
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            selected: selected,
            onSelected: (_) =>
                ref.read(maintenanceTabProvider.notifier).set(tab),
            selectedColor: AppColors.primaryDim,
            backgroundColor: AppColors.surfaceLight,
            side: BorderSide(
              color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.surfaceBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          );
        },
      ),
    );
  }
}
