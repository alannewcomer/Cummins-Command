import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/glass_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesStreamProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTypography.displaySmall),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Vehicles Section ──
          const SectionHeader(title: 'Vehicles', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          vehiclesAsync.when(
            data: (vehicles) {
              if (vehicles.isEmpty) {
                return _AddVehicleCard(ref: ref);
              }
              return Column(
                children: [
                  ...vehicles.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _VehicleCard(
                          vehicle: v,
                          isActive: v.id == activeVehicle?.id,
                          onTap: () {
                            ref.read(vehicleRepositoryProvider).setActiveVehicle(v.id);
                          },
                        ),
                      )),
                  _AddVehicleCard(ref: ref),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _AddVehicleCard(ref: ref),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── OBD Connection ──
          const SectionHeader(title: 'OBD Connection', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.bluetooth,
            title: 'OBDLink MX+ Setup',
            subtitle: 'Connect and configure your OBD adapter',
            onTap: () => context.push('/bluetooth-setup'),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Display ──
          const SectionHeader(title: 'Display', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.straighten,
            title: 'Units',
            subtitle: 'Imperial (°F, PSI, MPH)',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.vibration,
            title: 'Haptic Feedback',
            subtitle: 'Vibration on alerts and value changes',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.volume_up,
            title: 'Alert Sounds',
            subtitle: 'Audio alerts for critical thresholds',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── AI Settings ──
          const SectionHeader(title: 'AI Intelligence', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.diamond_outlined,
            title: 'AI Model',
            subtitle: 'Gemini 3.1 Pro (via Firebase)',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.auto_awesome,
            title: 'Auto-Analyze Drives',
            subtitle: 'Automatically analyze each drive with AI',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.psychology,
            title: 'Analysis Depth',
            subtitle: 'High — detailed insights with full reasoning',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Alert Thresholds ──
          const SectionHeader(title: 'Alert Thresholds', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.warning_amber,
            title: 'EGT Warning',
            subtitle: '1,100°F (Critical: 1,400°F)',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.thermostat,
            title: 'Coolant Warning',
            subtitle: '220°F (Critical: 240°F)',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.oil_barrel,
            title: 'Oil Pressure Warning',
            subtitle: '< 25 PSI (Critical: < 15 PSI)',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Data Management ──
          const SectionHeader(title: 'Data', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.cloud_download,
            title: 'Export All Data',
            subtitle: 'CSV export of all drive data',
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.storage,
            title: 'Cache Size',
            subtitle: 'Unlimited (offline-first)',
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Account ──
          const SectionHeader(title: 'Account', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          _AccountTile(),
          const SizedBox(height: AppSpacing.sm),
          _SignOutTile(),

          const SizedBox(height: AppSpacing.xxl),

          // ── Developer ──
          const SectionHeader(title: 'Developer', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            onTap: () => context.push('/debug'),
            child: Row(
              children: [
                Icon(Icons.bug_report_outlined, color: AppColors.warning, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Debug Logs', style: AppTypography.labelLarge),
                      const SizedBox(height: 2),
                      Text('OBD diagnostics & live data',
                          style: AppTypography.labelSmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.cloud_off,
            title: 'Upload Dev Logs',
            subtitle: 'Send debug logs to Firestore for remote debugging',
            trailing: Switch(
              value: ref.watch(devLogsCloudProvider),
              onChanged: (val) =>
                  ref.read(devLogsCloudProvider.notifier).toggle(val),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            onTap: () => context.push('/did-scanner'),
            child: Row(
              children: [
                Icon(Icons.radar, color: AppColors.warning, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DID Scanner', style: AppTypography.labelLarge),
                      const SizedBox(height: 2),
                      Text('Scan Mode \$22 enhanced PIDs',
                          style: AppTypography.labelSmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── About ──
          Center(
            child: Column(
              children: [
                Text('Cummins Command V2', style: AppTypography.labelMedium),
                const SizedBox(height: 4),
                Text('Version 2.0.0', style: AppTypography.labelSmall),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Validate and return a NetworkImage only for HTTPS URLs.
ImageProvider? _safePhotoUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return null;
  return NetworkImage(url);
}

class _AccountTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryDim,
            backgroundImage: _safePhotoUrl(user?.photoURL),
            child: user?.photoURL == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 22)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Signed In',
                  style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary),
                ),
                Text(
                  user?.email ?? '',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.critical),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await ref.read(authServiceProvider).signOut();
          // Router redirect handles navigation back to sign-in.
        }
      },
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.logout, size: 22, color: AppColors.critical),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign Out',
                  style: AppTypography.labelMedium.copyWith(color: AppColors.critical),
                ),
                Text('Remove account from this device', style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final dynamic vehicle;
  final bool isActive;
  final VoidCallback? onTap;

  const _VehicleCard({
    required this.vehicle,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      borderColor: isActive ? AppColors.primary.withValues(alpha: 0.5) : null,
      glowColor: isActive ? AppColors.primary : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_car,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.displayName,
                  style: AppTypography.labelLarge.copyWith(
                    color: isActive ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(vehicle.engine, style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryDim,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ACTIVE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddVehicleCard extends StatelessWidget {
  final WidgetRef ref;

  const _AddVehicleCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/add-vehicle'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.surfaceBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: const Icon(Icons.add, color: AppColors.textTertiary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Add Vehicle', style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.dataAccent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelMedium.copyWith(color: AppColors.textPrimary)),
                Text(subtitle, style: AppTypography.bodySmall),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
