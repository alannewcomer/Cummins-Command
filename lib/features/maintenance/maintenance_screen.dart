import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../models/maintenance_record.dart';
import '../../providers/maintenance_provider.dart';
import 'widgets/urgency_hero_card.dart';
import 'widgets/tab_chip_row.dart';
import 'widgets/dashboard_feed.dart';
import 'widgets/service_schedule_card.dart';
import 'widgets/checklist_card.dart';
import 'widgets/seasonal_card.dart';
import 'widgets/maintenance_history_card.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    // Bootstrap schedules on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapSchedules();
    });
  }

  Future<void> _bootstrapSchedules() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      await ref.read(maintenanceRepositoryProvider).initializeSchedules();
    } catch (_) {
      // Bootstrap may fail if user/vehicle not ready yet — retry on next build
      _bootstrapped = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(maintenanceTabProvider);

    // Re-attempt bootstrap when schedules stream resolves empty.
    // Covers the case where vehicle wasn't ready during initState.
    final schedulesAsync = ref.watch(serviceSchedulesProvider);
    if (schedulesAsync.hasValue && schedulesAsync.value!.isEmpty) {
      _bootstrapSchedules();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showActionSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            title: Text('Service Center', style: AppTypography.displaySmall),
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

          // Urgency Hero Card
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: UrgencyHeroCard(),
            ),
          ),

          // Tab Chip Row
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
              child: TabChipRow(),
            ),
          ),

          // Tab-specific content
          _buildTabContent(currentTab),
        ],
      ),
    );
  }

  Widget _buildTabContent(MaintenanceTab tab) {
    return switch (tab) {
      MaintenanceTab.dashboard => const DashboardFeed(),
      MaintenanceTab.schedule => const ScheduleTab(),
      MaintenanceTab.checklists => const ChecklistsTab(),
      MaintenanceTab.seasonal => const SeasonalTab(),
      MaintenanceTab.history => const HistoryTab(),
    };
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _ActionTile(
                icon: Icons.build_outlined,
                title: 'Log Service',
                subtitle: 'Record a completed maintenance service',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/maintenance/log-service');
                },
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.checklist_outlined,
                title: 'Run Checklist',
                subtitle: 'Start a pre-trip or storage checklist',
                onTap: () {
                  Navigator.pop(context);
                  ref.read(maintenanceTabProvider.notifier)
                      .set(MaintenanceTab.checklists);
                },
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.note_add_outlined,
                title: 'Quick Note',
                subtitle: 'Add a quick maintenance note',
                onTap: () {
                  Navigator.pop(context);
                  _showQuickNoteDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickNoteDialog(BuildContext context) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: notesController,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                final record = MaintenanceRecord(
                  id: '',
                  vehicleId: '',
                  category: 'Other',
                  title: titleController.text,
                  description: notesController.text.isEmpty
                      ? null
                      : notesController.text,
                  date: DateTime.now(),
                  isCompleted: true,
                  source: 'manual',
                );
                ref.read(maintenanceRepositoryProvider).add(record);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryDim,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      title: Text(title,
          style: AppTypography.labelLarge
              .copyWith(color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 0),
    );
  }
}
