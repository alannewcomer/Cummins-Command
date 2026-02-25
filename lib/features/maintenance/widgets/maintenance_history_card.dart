import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../config/maintenance_templates.dart';
import '../../../models/maintenance_record.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../widgets/common/glass_card.dart';

class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(maintenanceStreamProvider);

    return recordsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (records) {
        final completed = records.where((r) => r.isCompleted).toList();
        final filtered = _filterCategory != null
            ? completed.where((r) => r.category == _filterCategory).toList()
            : completed;

        // Get unique categories
        final categories =
            completed.map((r) => r.category).toSet().toList()..sort();

        return SliverList(
          delegate: SliverChildListDelegate([
            // Filter chips
            if (categories.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ChoiceChip(
                          label: Text('All',
                              style: AppTypography.labelSmall.copyWith(
                                color: _filterCategory == null
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              )),
                          selected: _filterCategory == null,
                          onSelected: (_) =>
                              setState(() => _filterCategory = null),
                          selectedColor: AppColors.primaryDim,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }
                      final cat = categories[index - 1];
                      return ChoiceChip(
                        label: Text(cat,
                            style: AppTypography.labelSmall.copyWith(
                              color: _filterCategory == cat
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            )),
                        selected: _filterCategory == cat,
                        onSelected: (_) =>
                            setState(() => _filterCategory = cat),
                        selectedColor: AppColors.primaryDim,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    },
                  ),
                ),
              ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history,
                          size: 48,
                          color: AppColors.textTertiary.withValues(alpha: 0.3)),
                      const SizedBox(height: AppSpacing.md),
                      Text('No service history yet',
                          style: AppTypography.displaySmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Completed services will appear here',
                          style: AppTypography.bodyMedium),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((r) => _HistoryRow(record: r)),
            const SizedBox(height: AppSpacing.xxxl),
          ]),
        );
      },
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  final MaintenanceRecord record;

  const _HistoryRow({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final icon = _categoryIcon(record.category);
    final sourceBadge = record.source;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        onLongPress: () => _confirmDelete(context, ref),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(record.title,
                            style: AppTypography.labelLarge
                                .copyWith(color: AppColors.textPrimary)),
                      ),
                      if (sourceBadge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _sourceColor(sourceBadge).withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          child: Text(
                            sourceBadge,
                            style: AppTypography.labelSmall.copyWith(
                              color: _sourceColor(sourceBadge),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.category} • ${dateFormat.format(record.date)}'
                    '${record.odometerReading != null ? ' • ${NumberFormat('#,##0').format(record.odometerReading)} mi' : ''}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            if (record.cost != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Text(
                  '\$${record.cost!.toStringAsFixed(0)}',
                  style: AppTypography.dataSmall
                      .copyWith(color: AppColors.dataAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text('Delete "${record.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(maintenanceRepositoryProvider).delete(record.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: TextStyle(color: AppColors.critical)),
          ),
        ],
      ),
    );
  }

  Color _sourceColor(String source) {
    return switch (source) {
      'scheduled' => AppColors.dataAccent,
      'checklist' => AppColors.success,
      'seasonal' => AppColors.warning,
      _ => AppColors.textTertiary,
    };
  }

  IconData _categoryIcon(String category) {
    // Try template lookup first
    for (final t in kServiceTypes) {
      if (t.name == category || t.id == category) return t.icon;
    }
    return switch (category) {
      'Oil Change' => Icons.oil_barrel,
      'Oil Filter' => Icons.oil_barrel,
      'Fuel Filter' => Icons.filter_alt,
      'Air Filter' => Icons.air,
      'Tire Rotation' => Icons.tire_repair,
      'Brake Service' => Icons.disc_full,
      'Battery' => Icons.battery_full,
      'DEF Fluid' => Icons.water_drop,
      'DPF Cleaning' => Icons.cleaning_services,
      'Coolant Flush' => Icons.thermostat,
      _ => Icons.build,
    };
  }
}
