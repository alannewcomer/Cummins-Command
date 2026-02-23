import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../config/pid_config.dart';
import '../../providers/live_data_provider.dart';
import '../../services/diagnostic_service.dart';

/// Live debug log viewer + raw OBD data stream.
class DebugLogScreen extends ConsumerStatefulWidget {
  const DebugLogScreen({super.key});

  @override
  ConsumerState<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends ConsumerState<DebugLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();
  final _entries = <DiagEntry>[];
  StreamSubscription<DiagEntry>? _sub;
  bool _autoScroll = true;
  DiagLevel _minLevel = DiagLevel.debug;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load existing entries
    _entries.addAll(diag.entries);
    // Listen for new ones
    _sub = diag.stream.listen((entry) {
      setState(() => _entries.add(entry));
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Debug', style: AppTypography.displaySmall),
        actions: [
          // DID Scanner nav
          IconButton(
            icon: const Icon(Icons.radar, color: AppColors.warning),
            tooltip: 'DID Scanner',
            onPressed: () => context.push('/did-scanner'),
          ),
          // Filter dropdown
          PopupMenuButton<DiagLevel>(
            icon: Icon(Icons.filter_list, color: AppColors.textSecondary),
            onSelected: (level) => setState(() => _minLevel = level),
            itemBuilder: (_) => DiagLevel.values
                .map((l) => PopupMenuItem(
                      value: l,
                      child: Row(
                        children: [
                          Icon(
                            _minLevel == l
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: _levelColor(l),
                          ),
                          const SizedBox(width: 8),
                          Text(l.name.toUpperCase(),
                              style: TextStyle(color: _levelColor(l))),
                        ],
                      ),
                    ))
                .toList(),
          ),
          // Auto-scroll toggle
          IconButton(
            icon: Icon(
              _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
              color:
                  _autoScroll ? AppColors.success : AppColors.textTertiary,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          // Copy all
          IconButton(
            icon: Icon(Icons.copy, color: AppColors.textSecondary),
            onPressed: () {
              final text = _filteredEntries.map((e) => e.toString()).join('\n');
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          // Clear
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.textSecondary),
            onPressed: () => setState(() => _entries.clear()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: const [
            Tab(text: 'LOGS'),
            Tab(text: 'LIVE DATA'),
            Tab(text: 'PID STATUS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogView(),
          _buildLiveDataView(),
          _buildPidStatusView(),
        ],
      ),
    );
  }

  List<DiagEntry> get _filteredEntries =>
      _entries.where((e) => e.level.index >= _minLevel.index).toList();

  Widget _buildLogView() {
    final filtered = _filteredEntries;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report_outlined,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No log entries', style: AppTypography.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Connect OBD to see diagnostic data',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: filtered.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return _LogEntryTile(entry: entry);
      },
    );
  }

  Widget _buildLiveDataView() {
    final liveData = ref.watch(liveDataProvider);

    if (liveData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No live data', style: AppTypography.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Connect OBD and start polling to see values',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      );
    }

    final sorted = liveData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => Divider(
        color: AppColors.surfaceBorder,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final e = sorted[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  e.key,
                  style: AppTypography.labelMedium.copyWith(
                    fontFamily: 'JetBrains Mono',
                    color: AppColors.dataAccent,
                  ),
                ),
              ),
              Text(
                e.value.toStringAsFixed(2),
                style: AppTypography.labelLarge.copyWith(
                  fontFamily: 'JetBrains Mono',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPidStatusView() {
    final statusAsync = ref.watch(pidStatusProvider);

    return statusAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e', style: AppTypography.bodySmall),
      ),
      data: (statusMap) {
        if (statusMap.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.playlist_add_check,
                    size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('No PID data yet', style: AppTypography.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  'Start OBD polling to see PID status',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          );
        }

        // Group by protocol
        final groups = <PidProtocol, List<PidStatus>>{
          PidProtocol.obd2: [],
          PidProtocol.mode22: [],
        };
        for (final s in statusMap.values) {
          groups[s.protocol]?.add(s);
        }
        for (final list in groups.values) {
          list.sort((a, b) => a.id.compareTo(b.id));
        }

        // Summary stats
        final active = statusMap.values.where((s) => s.successCount > 0).length;
        final failing = statusMap.values.where((s) =>
            s.successCount == 0 && s.failureCount > 0).length;
        final mixed = statusMap.values.where((s) =>
            s.successCount > 0 && s.failureCount > 0).length;
        final obd = ref.read(obdServiceProvider);

        final sections = <Widget>[
          // Protocol + health summary banner
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.router, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Protocol: ${obd.protocol.name.toUpperCase()}',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${statusMap.length} PIDs tracked',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _SummaryChip(
                      label: 'OK',
                      count: active,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: 'MIXED',
                      count: mixed,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    _SummaryChip(
                      label: 'FAIL',
                      count: failing,
                      color: AppColors.critical,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];

        for (final proto in PidProtocol.values) {
          final list = groups[proto] ?? [];
          if (list.isEmpty) continue;

          sections.add(_PidGroupHeader(
            label: proto.name.toUpperCase(),
            count: list.length,
          ));
          for (final status in list) {
            sections.add(_PidStatusRow(status: status));
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 0),
          children: sections,
        );
      },
    );
  }

  Color _levelColor(DiagLevel level) {
    switch (level) {
      case DiagLevel.debug:
        return AppColors.textTertiary;
      case DiagLevel.info:
        return AppColors.dataAccent;
      case DiagLevel.warn:
        return AppColors.warning;
      case DiagLevel.error:
        return AppColors.critical;
    }
  }
}

// ─── Summary Chip ───

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── PID Status Widgets ───

class _PidGroupHeader extends StatelessWidget {
  final String label;
  final int count;

  const _PidGroupHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PidStatusRow extends StatefulWidget {
  final PidStatus status;

  const _PidStatusRow({required this.status});

  @override
  State<_PidStatusRow> createState() => _PidStatusRowState();
}

class _PidStatusRowState extends State<_PidStatusRow> {
  bool _expanded = false;

  Color get _indicatorColor {
    final s = widget.status;
    if (s.successCount > 0 && s.failureCount == 0) return AppColors.success;
    if (s.successCount > 0 && s.failureCount > 0) return AppColors.warning;
    if (s.successCount == 0 && s.failureCount > 0) return AppColors.critical;
    return AppColors.textTertiary; // never tried
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final hasValue = s.lastValue != null;
    final hasRaw = s.lastRawHex != null && s.lastRawHex!.isNotEmpty;

    return GestureDetector(
      onTap: hasRaw ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Color indicator dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _indicatorColor,
                  ),
                ),
                const SizedBox(width: 8),
                // PID id + command
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.id,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.command,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Counts
                          Text(
                            '${s.successCount} ok / ${s.failureCount} fail',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              color: s.failureCount > 0
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                            ),
                          ),
                          if (s.failReason != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              s.failReason!,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 10,
                                color: AppColors.critical,
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Last value
                          if (hasValue)
                            Text(
                              '${s.lastValue!.toStringAsFixed(2)} ${s.lastUnit ?? ''}',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.dataAccent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Expand chevron if raw hex available
                if (hasRaw)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
            // Expanded raw hex view
            if (_expanded && hasRaw) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Text(
                  s.lastRawHex!,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 9,
                    color: AppColors.textSecondary,
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

class _LogEntryTile extends StatelessWidget {
  final DiagEntry entry;
  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ts = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
        '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
        '${entry.timestamp.second.toString().padLeft(2, '0')}.'
        '${entry.timestamp.millisecond.toString().padLeft(3, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            ts,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 6),
          // Level indicator
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          // Tag
          SizedBox(
            width: 36,
            child: Text(
              entry.tag,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Message + detail
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: entry.message,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (entry.detail != null)
                    TextSpan(
                      text: ' ${entry.detail}',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
    switch (entry.level) {
      case DiagLevel.debug:
        return AppColors.textTertiary;
      case DiagLevel.info:
        return AppColors.dataAccent;
      case DiagLevel.warn:
        return AppColors.warning;
      case DiagLevel.error:
        return AppColors.critical;
    }
  }
}

