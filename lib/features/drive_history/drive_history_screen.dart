import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/drive_session.dart';
import '../../providers/drives_provider.dart';
import '../../widgets/cards/drive_card.dart';

/// Available filter tags for drive history.
const _filterTags = ['All', 'Towing', 'Commute', 'Mountain', 'Track'];

class DriveHistoryScreen extends ConsumerStatefulWidget {
  const DriveHistoryScreen({super.key});

  @override
  ConsumerState<DriveHistoryScreen> createState() =>
      _DriveHistoryScreenState();
}

class _DriveHistoryScreenState extends ConsumerState<DriveHistoryScreen> {
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final drivesAsync = ref.watch(drivesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            title: Text('Drive History', style: AppTypography.displaySmall),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list, size: 22),
                color: AppColors.textSecondary,
                onPressed: () => _showFilterSheet(context),
              ),
            ],
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: _FilterChips(
              tags: _filterTags,
              active: _activeFilter,
              onSelected: (tag) {
                HapticFeedback.lightImpact();
                setState(() => _activeFilter = tag);
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

          // Drive list
          drivesAsync.when(
            data: (drives) {
              final filtered = _filterDrives(drives);
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(hasFilter: _activeFilter != 'All'),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= filtered.length) return null;
                      final drive = filtered[index];
                      return _StaggeredDriveCard(
                        index: index,
                        drive: drive,
                        onTap: () => context.push('/drives/${drive.id}'),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ShimmerDriveCard(index: index),
                  ),
                  childCount: 5,
                ),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(error: error.toString()),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }

  List<DriveSession> _filterDrives(List<DriveSession> drives) {
    if (_activeFilter == 'All') return drives;
    final filterLower = _activeFilter.toLowerCase();
    return drives
        .where((d) => d.tags.any((t) => t.toLowerCase() == filterLower))
        .toList();
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
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
              Text('Filter Drives', style: AppTypography.displaySmall),
              const SizedBox(height: AppSpacing.lg),
              Text('By Tag', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _filterTags.map((tag) {
                  final isActive = _activeFilter == tag;
                  return FilterChip(
                    label: Text(tag),
                    selected: isActive,
                    onSelected: (_) {
                      setState(() => _activeFilter = tag);
                      Navigator.pop(context);
                    },
                    selectedColor: AppColors.primaryDim,
                    checkmarkColor: AppColors.primary,
                    labelStyle: AppTypography.labelMedium.copyWith(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      side: BorderSide(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.surfaceBorder,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceLight,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('By Health Score', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _HealthFilterChip(
                    label: 'Excellent',
                    color: AppColors.success,
                    range: '80-100',
                  ),
                  _HealthFilterChip(
                    label: 'Good',
                    color: AppColors.warning,
                    range: '60-79',
                  ),
                  _HealthFilterChip(
                    label: 'Needs Review',
                    color: AppColors.critical,
                    range: '<60',
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Filter Chips Row ───

class _FilterChips extends StatelessWidget {
  final List<String> tags;
  final String active;
  final void Function(String) onSelected;

  const _FilterChips({
    required this.tags,
    required this.active,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final tag = tags[index];
          final isActive = active == tag;

          return GestureDetector(
            onTap: () => onSelected(tag),
            child: AnimatedContainer(
              duration: AppTheme.animDuration,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.round),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Center(
                child: Text(
                  tag,
                  style: AppTypography.labelMedium.copyWith(
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Staggered Drive Card with fade-in animation ───

class _StaggeredDriveCard extends StatefulWidget {
  final int index;
  final DriveSession drive;
  final VoidCallback onTap;

  const _StaggeredDriveCard({
    required this.index,
    required this.drive,
    required this.onTap,
  });

  @override
  State<_StaggeredDriveCard> createState() => _StaggeredDriveCardState();
}

class _StaggeredDriveCardState extends State<_StaggeredDriveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Stagger: 60ms per card, capped at 600ms
    final delay = (widget.index * 60).clamp(0, 600);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DriveCard(
            drive: widget.drive,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Loading Card ───

class _ShimmerDriveCard extends StatefulWidget {
  final int index;
  const _ShimmerDriveCard({required this.index});

  @override
  State<_ShimmerDriveCard> createState() => _ShimmerDriveCardState();
}

class _ShimmerDriveCardState extends State<_ShimmerDriveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmer = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        return Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            gradient: LinearGradient(
              begin: Alignment(_shimmer.value - 1, 0),
              end: Alignment(_shimmer.value, 0),
              colors: const [
                AppColors.surface,
                AppColors.surfaceLight,
                AppColors.surface,
              ],
            ),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
        );
      },
    );
  }
}

// ─── Empty State ───

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({this.hasFilter = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Truck icon with subtle styling
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              hasFilter ? 'No Matching Drives' : 'No Drives Yet',
              style: AppTypography.displaySmall.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasFilter
                  ? 'No drives match the current filter.\nTry adjusting your filters.'
                  : 'Start recording drives to build your\nhistory and unlock AI insights.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!hasFilter) ...[
              const SizedBox(height: AppSpacing.xxl),
              GestureDetector(
                onTap: () => context.push('/bluetooth-setup'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.round),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fiber_manual_record,
                          size: 14, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Start Recording',
                        style: AppTypography.button,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Error State ───

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.critical),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Error Loading Drives',
              style: AppTypography.displaySmall.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Health Filter Chip ───

class _HealthFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final String range;

  const _HealthFilterChip({
    required this.label,
    required this.color,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($range)',
            style: AppTypography.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
