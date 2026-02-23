import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../providers/data_explorer_provider.dart';

/// Parameter colors for multi-overlay chart.
const _paramColors = <Color>[
  Color(0xFF00AAFF), // Electric blue
  Color(0xFFFF6B00), // Cummins orange
  Color(0xFF00E676), // Green
  Color(0xFFE040FB), // Purple
  Color(0xFFFFAB00), // Amber
  Color(0xFF00BCD4), // Cyan
];

class DataExplorerScreen extends ConsumerStatefulWidget {
  const DataExplorerScreen({super.key});

  @override
  ConsumerState<DataExplorerScreen> createState() => _DataExplorerScreenState();
}

class _DataExplorerScreenState extends ConsumerState<DataExplorerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _emptyStateController;
  late final Animation<double> _emptyPulse;

  final _zoomPanBehavior = ZoomPanBehavior(
    enablePinching: true,
    enablePanning: true,
    enableDoubleTapZooming: true,
    enableSelectionZooming: true,
    selectionRectBorderColor: AppColors.primary.withValues(alpha: 0.5),
    selectionRectColor: AppColors.primary.withValues(alpha: 0.08),
    zoomMode: ZoomMode.x,
  );

  final _crosshairBehavior = CrosshairBehavior(
    enable: true,
    activationMode: ActivationMode.longPress,
    lineColor: AppColors.textTertiary.withValues(alpha: 0.3),
    lineWidth: 1,
    lineDashArray: const [4, 4],
  );

  final _trackballBehavior = TrackballBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
    tooltipAlignment: ChartAlignment.near,
    tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
    markerSettings: const TrackballMarkerSettings(
      markerVisibility: TrackballVisibilityMode.visible,
      height: 6,
      width: 6,
      borderWidth: 2,
    ),
    tooltipSettings: InteractiveTooltip(
      color: AppColors.surface,
      borderColor: AppColors.surfaceBorder,
      borderWidth: 1,
      textStyle: AppTypography.labelSmall.copyWith(
        color: AppColors.textPrimary,
      ),
      format: 'point.y',
    ),
    lineColor: AppColors.primary.withValues(alpha: 0.4),
    lineWidth: 1,
  );

  @override
  void initState() {
    super.initState();
    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _emptyPulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _emptyStateController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emptyStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedParams = ref.watch(selectedParamsProvider);
    final timeRange = ref.watch(timeRangeProvider);
    final explorerData = ref.watch(explorerDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Data Explorer', style: AppTypography.displaySmall),
        actions: [
          if (selectedParams.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.textSecondary,
              onPressed: () => ref.invalidate(explorerDataProvider),
            ),
          IconButton(
            icon: const Icon(Icons.tune, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => _showParameterPicker(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected parameter chips
          _SelectedParamsRow(
            selectedParams: selectedParams,
            onRemove: (id) => ref.read(selectedParamsProvider.notifier).toggle(id),
            onAdd: () => _showParameterPicker(context),
          ),

          // Time range selector
          _TimeRangeSelector(
            current: timeRange.preset,
            onSelect: (preset) {
              HapticFeedback.lightImpact();
              ref.read(timeRangeProvider.notifier).setPreset(preset);
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Main chart area
          Expanded(
            child: selectedParams.isEmpty
                ? _EmptyState(pulseAnimation: _emptyPulse)
                : explorerData.when(
                    data: (data) {
                      if (data.isEmpty) {
                        return _NoDataState();
                      }
                      return _ExplorerChart(
                        data: data,
                        selectedParams: selectedParams,
                        zoomPanBehavior: _zoomPanBehavior,
                        crosshairBehavior: _crosshairBehavior,
                        trackballBehavior: _trackballBehavior,
                      );
                    },
                    loading: () => const _ChartLoadingState(),
                    error: (error, _) => _ErrorState(error: error.toString()),
                  ),
          ),

          // Stats panel
          if (selectedParams.isNotEmpty)
            explorerData.when(
              data: (data) => _StatsPanel(
                data: data,
                selectedParams: selectedParams,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),

      // Ask AI FAB
      floatingActionButton: selectedParams.isNotEmpty
          ? _AskAiFab(
              onTap: () {
                HapticFeedback.mediumImpact();
                context.go('/ai');
              },
            )
          : null,
    );
  }

  void _showParameterPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ParameterPickerSheet(),
    );
  }
}

// ─── Selected Parameters Row ───

class _SelectedParamsRow extends StatelessWidget {
  final List<String> selectedParams;
  final void Function(String) onRemove;
  final VoidCallback onAdd;

  const _SelectedParamsRow({
    required this.selectedParams,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          // Add button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Add',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Selected param chips
          ...selectedParams.asMap().entries.map((entry) {
            final index = entry.key;
            final paramId = entry.value;
            final pid = PidRegistry.get(paramId);
            final color = _paramColors[index % _paramColors.length];

            return Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: AnimatedContainer(
                duration: AppTheme.animDuration,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                  ),
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
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pid?.shortName ?? paramId.toUpperCase(),
                      style: AppTypography.labelMedium.copyWith(color: color),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemove(paramId),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: color.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Time Range Selector ───

class _TimeRangeSelector extends StatelessWidget {
  final TimeRangePreset current;
  final void Function(TimeRangePreset) onSelect;

  const _TimeRangeSelector({
    required this.current,
    required this.onSelect,
  });

  static const _presets = [
    (TimeRangePreset.days7, '7D'),
    (TimeRangePreset.days30, '30D'),
    (TimeRangePreset.days90, '90D'),
    (TimeRangePreset.year1, '1Y'),
    (TimeRangePreset.allTime, 'All'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: _presets.map((preset) {
          final isSelected = current == preset.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () => onSelect(preset.$1),
                child: AnimatedContainer(
                  duration: AppTheme.animDuration,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : AppColors.surfaceBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      preset.$2,
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Chart ───

class _ExplorerChart extends StatelessWidget {
  final Map<String, List<MapEntry<DateTime, double>>> data;
  final List<String> selectedParams;
  final ZoomPanBehavior zoomPanBehavior;
  final CrosshairBehavior crosshairBehavior;
  final TrackballBehavior trackballBehavior;

  const _ExplorerChart({
    required this.data,
    required this.selectedParams,
    required this.zoomPanBehavior,
    required this.crosshairBehavior,
    required this.trackballBehavior,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBorderWidth: 0,
        margin: const EdgeInsets.all(AppSpacing.sm),
        zoomPanBehavior: zoomPanBehavior,
        crosshairBehavior: crosshairBehavior,
        trackballBehavior: trackballBehavior,
        primaryXAxis: DateTimeAxis(
          majorGridLines: MajorGridLines(
            width: 0.5,
            color: AppColors.surfaceBorder.withValues(alpha: 0.5),
            dashArray: const [4, 4],
          ),
          minorGridLines: const MinorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          labelStyle: AppTypography.labelSmall,
          majorTickLines: const MajorTickLines(size: 0),
          edgeLabelPlacement: EdgeLabelPlacement.shift,
        ),
        // Create axes for each selected parameter
        axes: _buildYAxes(),
        series: _buildSeries(),
        legend: Legend(
          isVisible: selectedParams.length > 1,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
          textStyle: AppTypography.labelSmall,
          iconHeight: 8,
          iconWidth: 8,
          itemPadding: 12,
        ),
      ),
    );
  }

  List<NumericAxis> _buildYAxes() {
    final axes = <NumericAxis>[];

    for (var i = 0; i < selectedParams.length; i++) {
      final paramId = selectedParams[i];
      final pid = PidRegistry.get(paramId);
      final color = _paramColors[i % _paramColors.length];
      final isFirst = i == 0;
      final isLast = i == selectedParams.length - 1;

      axes.add(NumericAxis(
        name: paramId,
        opposedPosition: i.isOdd,
        isVisible: isFirst || isLast || selectedParams.length <= 3,
        majorGridLines: MajorGridLines(
          width: isFirst ? 0.5 : 0,
          color: AppColors.surfaceBorder.withValues(alpha: 0.3),
          dashArray: const [4, 4],
        ),
        minorGridLines: const MinorGridLines(width: 0),
        axisLine: AxisLine(
          width: 2,
          color: color.withValues(alpha: 0.4),
        ),
        labelStyle: AppTypography.labelSmall.copyWith(
          color: color.withValues(alpha: 0.8),
          fontSize: 9,
        ),
        majorTickLines: const MajorTickLines(size: 0),
        title: AxisTitle(
          text: pid?.unit ?? '',
          textStyle: AppTypography.labelSmall.copyWith(
            color: color.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
      ));
    }
    return axes;
  }

  List<LineSeries<MapEntry<DateTime, double>, DateTime>> _buildSeries() {
    return selectedParams.asMap().entries.map((entry) {
      final i = entry.key;
      final paramId = entry.value;
      final pid = PidRegistry.get(paramId);
      final color = _paramColors[i % _paramColors.length];
      final points = data[paramId] ?? [];

      return LineSeries<MapEntry<DateTime, double>, DateTime>(
        name: pid?.shortName ?? paramId.toUpperCase(),
        dataSource: points,
        xValueMapper: (datum, _) => datum.key,
        yValueMapper: (datum, _) => datum.value,
        yAxisName: paramId,
        color: color,
        width: 2,
        animationDuration: 800,
        enableTooltip: true,
        markerSettings: MarkerSettings(
          isVisible: points.length < 100,
          height: 4,
          width: 4,
          borderColor: color,
          color: AppColors.surface,
          borderWidth: 2,
        ),
      );
    }).toList();
  }
}

// ─── Stats Panel ───

class _StatsPanel extends StatelessWidget {
  final Map<String, List<MapEntry<DateTime, double>>> data;
  final List<String> selectedParams;

  const _StatsPanel({
    required this.data,
    required this.selectedParams,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats header
          Row(
            children: [
              Text('Statistics', style: AppTypography.labelMedium),
              const Spacer(),
              Text(
                '${selectedParams.length} parameter${selectedParams.length != 1 ? 's' : ''}',
                style: AppTypography.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Stats grid
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedParams.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final paramId = selectedParams[index];
                final pid = PidRegistry.get(paramId);
                final color =
                    _paramColors[index % _paramColors.length];
                final points = data[paramId] ?? [];

                if (points.isEmpty) {
                  return _StatChip(
                    color: color,
                    label: pid?.shortName ?? paramId,
                    min: '--',
                    max: '--',
                    mean: '--',
                  );
                }

                final values = points.map((e) => e.value).toList()..sort();
                final min = values.first;
                final max = values.last;
                final mean = values.reduce((a, b) => a + b) / values.length;

                return _StatChip(
                  color: color,
                  label: pid?.shortName ?? paramId,
                  min: min.toStringAsFixed(1),
                  max: max.toStringAsFixed(1),
                  mean: mean.toStringAsFixed(1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Color color;
  final String label;
  final String min;
  final String max;
  final String mean;

  const _StatChip({
    required this.color,
    required this.label,
    required this.min,
    required this.max,
    required this.mean,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniStat(label: 'Min', value: min, color: AppColors.dataAccent),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(label: 'Max', value: max, color: AppColors.warning),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(label: 'Avg', value: mean, color: AppColors.textPrimary),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(fontSize: 8),
        ),
        Text(
          value,
          style: AppTypography.dataSmall.copyWith(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ─── Empty / Loading / Error States ───

class _EmptyState extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _EmptyState({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: pulseAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.dataAccent
                          .withValues(alpha: 0.06 * pulseAnimation.value),
                      border: Border.all(
                        color: AppColors.dataAccent
                            .withValues(alpha: 0.15 * pulseAnimation.value),
                      ),
                    ),
                    child: Icon(
                      Icons.insights_outlined,
                      size: 36,
                      color: AppColors.dataAccent
                          .withValues(alpha: 0.3 + 0.3 * pulseAnimation.value),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Select Parameters to Explore',
              style: AppTypography.displaySmall.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap the + button above or use the tune icon\nto add parameters and visualize your data',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDataState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.query_stats,
            size: 48,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No Data Available',
            style: AppTypography.displaySmall.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Record some drives to see data\nin this time range',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChartLoadingState extends StatelessWidget {
  const _ChartLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Loading data...',
            style: AppTypography.labelMedium,
          ),
        ],
      ),
    );
  }
}

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
              'Error Loading Data',
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

// ─── Ask AI FAB ───

class _AskAiFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AskAiFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.round),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onTap,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.diamond_outlined, size: 18),
        label: Text('Ask AI', style: AppTypography.button),
      ),
    );
  }
}

// ─── Parameter Picker Bottom Sheet ───

class _ParameterPickerSheet extends ConsumerWidget {
  const _ParameterPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedParams = ref.watch(selectedParamsProvider);
    final filteredPids = ref.watch(filteredPidsProvider);
    final searchQuery = ref.watch(pidSearchProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      'Select Parameters',
                      style: AppTypography.displaySmall.copyWith(fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${selectedParams.length}/6',
                      style: AppTypography.labelMedium.copyWith(
                        color: selectedParams.length >= 6
                            ? AppColors.warning
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search parameters...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: AppColors.textTertiary,
                              size: 18,
                            ),
                            onPressed: () => ref
                                .read(pidSearchProvider.notifier)
                                .setQuery(''),
                          )
                        : null,
                  ),
                  onChanged: (q) =>
                      ref.read(pidSearchProvider.notifier).setQuery(q),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // PID list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: filteredPids.length,
                  itemBuilder: (context, index) {
                    final pid = filteredPids[index];
                    final isSelected = selectedParams.contains(pid.id);
                    final colorIndex = selectedParams.indexOf(pid.id);
                    final color = isSelected && colorIndex >= 0
                        ? _paramColors[colorIndex % _paramColors.length]
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AnimatedContainer(
                        duration: AppTheme.animDuration,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                            side: BorderSide(
                              color: isSelected
                                  ? (color ?? AppColors.primary)
                                      .withValues(alpha: 0.4)
                                  : AppColors.surfaceBorder,
                            ),
                          ),
                          tileColor: isSelected
                              ? (color ?? AppColors.primary)
                                  .withValues(alpha: 0.06)
                              : AppColors.surfaceLight,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? (color ?? AppColors.primary)
                                      .withValues(alpha: 0.15)
                                  : AppColors.surface,
                            ),
                            child: Center(
                              child: Text(
                                pid.shortName.length > 3
                                    ? pid.shortName.substring(0, 3)
                                    : pid.shortName,
                                style: AppTypography.labelSmall.copyWith(
                                  color: isSelected
                                      ? (color ?? AppColors.primary)
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            pid.name,
                            style: AppTypography.labelMedium.copyWith(
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          subtitle: Text(
                            '${pid.unit} | ${pid.protocol == PidProtocol.mode22 ? 'Mode 22' : 'OBD2'}',
                            style: AppTypography.labelSmall,
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: color ?? AppColors.primary,
                                  size: 22,
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  color: AppColors.surfaceBorder,
                                  size: 22,
                                ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(selectedParamsProvider.notifier)
                                .toggle(pid.id);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Done button
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  MediaQuery.of(context).padding.bottom + AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
