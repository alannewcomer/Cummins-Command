import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../config/constants.dart';
import '../../models/drive_route.dart';
import '../../providers/drives_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/cards/drive_card.dart';
import '../../widgets/common/glass_card.dart';

class RouteDetailScreen extends ConsumerWidget {
  final String routeId;

  const RouteDetailScreen({super.key, required this.routeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAsync = ref.watch(routeDetailProvider(routeId));
    final drivesAsync = ref.watch(routeDrivesProvider(routeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: routeAsync.when(
        data: (route) {
          if (route == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Route Not Found',
                      style:
                          AppTypography.displaySmall.copyWith(fontSize: 16)),
                  const SizedBox(height: AppSpacing.xxl),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: false,
                pinned: true,
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: const Icon(Icons.arrow_back, size: 18),
                  ),
                  onPressed: () => context.pop(),
                ),
                title: GestureDetector(
                  onTap: () => _editRouteName(context, ref, route),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(route.name,
                          style: AppTypography.displaySmall
                              .copyWith(fontSize: 16)),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.edit,
                          size: 12, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),

              // Stats overview
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _RouteStatsCard(route: route),
                ),
              ),

              // AI insights
              if (route.aiRouteInsights != null &&
                  route.aiRouteInsights!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: GlassCard(
                      glowColor: AppColors.primary,
                      borderColor:
                          AppColors.primary.withValues(alpha: 0.2),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.diamond_outlined,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Text('Route Insights',
                                  style: AppTypography.labelMedium
                                      .copyWith(color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(route.aiRouteInsights!,
                              style: AppTypography.aiText
                                  .copyWith(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg)),

              // Drives header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Text('Drives on This Route',
                      style:
                          AppTypography.displaySmall.copyWith(fontSize: 14)),
                ),
              ),

              const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.md)),

              // Drive list
              drivesAsync.when(
                data: (drives) {
                  if (drives.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxxl),
                        child: Center(
                            child: Text('No drives on this route yet.')),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final drive = drives[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.md),
                            child: DriveCard(
                              drive: drive,
                              onTap: () =>
                                  context.push('/drives/${drive.id}'),
                            ),
                          );
                        },
                        childCount: drives.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxxl),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e')),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      MediaQuery.of(context).padding.bottom + AppSpacing.xxxl,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _editRouteName(
      BuildContext context, WidgetRef ref, DriveRoute route) {
    final controller = TextEditingController(text: route.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Route'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(hintText: 'Route name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _updateRouteName(ref, route.id, name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateRouteName(WidgetRef ref, String routeId, String name) {
    final uid = ref.read(userIdProvider);
    final vehicle = ref.read(activeVehicleProvider);
    if (uid == null || vehicle == null) return;

    FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(vehicle.id)
        .collection(AppConstants.routesSubcollection)
        .doc(routeId)
        .update({'name': name});
  }
}

class _RouteStatsCard extends StatelessWidget {
  final DriveRoute route;

  const _RouteStatsCard({required this.route});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Drive count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${route.driveCount}',
                style: AppTypography.dataLarge.copyWith(
                  color: AppColors.primary,
                  fontSize: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                route.driveCount == 1 ? 'DRIVE' : 'DRIVES',
                style: AppTypography.labelSmall.copyWith(
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Stats grid
          Row(
            children: [
              _StatItem(
                label: 'AVG MPG',
                value: route.avgMPG?.toStringAsFixed(1) ?? '--',
                color: AppColors.success,
              ),
              _StatItem(
                label: 'AVG DURATION',
                value: route.avgDuration != null
                    ? _formatDuration(route.avgDuration!)
                    : '--',
                color: AppColors.dataAccent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _StatItem(
                label: 'AVG MAX EGT',
                value: route.avgMaxEGT != null
                    ? '${route.avgMaxEGT!.toStringAsFixed(0)}F'
                    : '--',
                color: AppColors.warning,
              ),
              _StatItem(
                label: 'AVG MAX BOOST',
                value: route.avgMaxBoost != null
                    ? '${route.avgMaxBoost!.toStringAsFixed(1)} PSI'
                    : '--',
                color: AppColors.dataAccent,
              ),
            ],
          ),
          if (route.bestMPG != null || route.worstMPG != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _StatItem(
                  label: 'BEST MPG',
                  value: route.bestMPG?.toStringAsFixed(1) ?? '--',
                  color: AppColors.success,
                ),
                _StatItem(
                  label: 'WORST MPG',
                  value: route.worstMPG?.toStringAsFixed(1) ?? '--',
                  color: AppColors.critical,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final s = seconds.toInt();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.dataMedium.copyWith(
              color: color,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 8,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
