import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../config/constants.dart';
import '../../providers/maintenance_provider.dart';
import '../../models/maintenance_record.dart';
import '../../widgets/common/glass_card.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenanceAsync = ref.watch(maintenanceStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Maintenance Log', style: AppTypography.displaySmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF export coming soon')),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: maintenanceAsync.when(
        data: (records) => records.isEmpty
            ? _buildEmptyState()
            : _buildMaintenanceList(context, records),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildEmptyState(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.build_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.3)),
          const SizedBox(height: AppSpacing.lg),
          Text('No Maintenance Records', style: AppTypography.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap + to add your first service record',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceList(BuildContext context, List<MaintenanceRecord> records) {
    // Split into upcoming and completed
    final upcoming = records.where((r) => !r.isCompleted).toList();
    final completed = records.where((r) => r.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (upcoming.isNotEmpty) ...[
          const SectionHeader(title: 'Upcoming', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          ...upcoming.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MaintenanceCard(record: r, isUpcoming: true),
              )),
        ],
        if (completed.isNotEmpty) ...[
          SectionHeader(
            title: 'Service History',
            padding: EdgeInsets.only(
              top: upcoming.isNotEmpty ? AppSpacing.lg : 0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...completed.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MaintenanceCard(record: r, isUpcoming: false),
              )),
        ],
      ],
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    String? selectedCategory;
    final titleController = TextEditingController();
    final costController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
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
              Text('Add Service Record', style: AppTypography.displaySmall),
              const SizedBox(height: AppSpacing.xl),
              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                dropdownColor: AppColors.surface,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Category'),
                items: AppConstants.maintenanceCategories.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) => setState(() => selectedCategory = val),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: titleController,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Cost (\$)', prefixText: '\$ '),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedCategory != null) {
                      final record = MaintenanceRecord(
                        id: '',
                        vehicleId: '',
                        category: selectedCategory!,
                        title: titleController.text.isNotEmpty
                            ? titleController.text
                            : selectedCategory!,
                        date: DateTime.now(),
                        cost: double.tryParse(costController.text),
                        isCompleted: true,
                      );
                      ref.read(maintenanceRepositoryProvider).add(record);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceRecord record;
  final bool isUpcoming;

  const _MaintenanceCard({required this.record, required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final color = isUpcoming ? AppColors.warning : AppColors.success;
    final iconData = _categoryIcon(record.category);

    return GlassCard(
      borderColor: isUpcoming ? AppColors.warning.withValues(alpha: 0.3) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.category} • ${dateFormat.format(record.date)}',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          if (record.cost != null)
            Text(
              '\$${record.cost!.toStringAsFixed(0)}',
              style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent),
            ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'Oil Change' => Icons.oil_barrel,
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
