import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../providers/ai_provider.dart';
import '../../providers/ai_job_provider.dart';
import '../../models/maintenance_record.dart';
import '../../providers/drives_provider.dart';
import '../../providers/maintenance_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/ai/ai_chat_bubble.dart';
import '../../widgets/common/glass_card.dart';

class AiInsightsScreen extends ConsumerStatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  ConsumerState<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends ConsumerState<AiInsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _sendMessage([String? prefilled]) {
    final text = (prefilled ?? _chatController.text).trim();
    if (text.isEmpty) return;
    _chatController.clear();

    // Build history BEFORE adding current message to avoid duplication
    final history = ref.read(chatHistoryProvider).map((msg) {
      return {'role': msg.role == 'ai' ? 'model' : 'user', 'content': msg.content};
    }).toList();

    ref.read(chatHistoryProvider.notifier).addUserMessage(text);
    ref.read(aiLoadingProvider.notifier).setLoading(true);

    () async {
      try {
        final aiService = ref.read(aiServiceProvider);
        final response = await aiService.chat(text, history);
        ref.read(chatHistoryProvider.notifier).addAiMessage(response);
      } catch (e) {
        debugPrint('AI chat error: $e');
        ref.read(chatHistoryProvider.notifier).addAiMessage(
          'AI service error: $e',
        );
      } finally {
        ref.read(aiLoadingProvider.notifier).setLoading(false);
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('AI Insights', style: AppTypography.displaySmall),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          labelStyle: AppTypography.labelMedium,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'ANALYZE'),
            Tab(text: 'PREDICTIONS'),
            Tab(text: 'ASK GEMINI'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _AnalyzeTab(),
          const _PredictionsTab(),
          _ChatTab(
            controller: _chatController,
            onSend: _sendMessage,
            ref: ref,
          ),
        ],
      ),
    );
  }
}

// ─── Analyze Tab ───

class _AnalyzeTab extends ConsumerWidget {
  const _AnalyzeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivesAsync = ref.watch(drivesStreamProvider);

    return drivesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Text('Error loading drives: $e', style: AppTypography.bodyMedium),
      ),
      data: (drives) {
        if (drives.isEmpty) {
          return _buildEmptyState(
            icon: Icons.route,
            title: 'No Drives Yet',
            subtitle: 'Complete your first drive to run AI-powered analysis.',
          );
        }

        final stats = ref.watch(scopeStatsProvider);
        final analysisState = ref.watch(analysisResultProvider);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const _ScopeSelector(),
            const SizedBox(height: AppSpacing.lg),
            _QuickStatsCard(stats: stats),
            const SizedBox(height: AppSpacing.lg),
            _AnalyzeButton(
              hasDrives: stats.driveCount > 0,
              isLoading: analysisState is AsyncLoading,
              onPressed: () {
                final scope = ref.read(analysisScopeProvider);
                ref.read(analysisResultProvider.notifier).runAnalysis(scope, drives);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            // Results / error display
            analysisState.when(
              loading: () => const SizedBox.shrink(), // button already shows spinner
              error: (e, _) => GlassCard(
                glowColor: AppColors.critical,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.critical, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Analysis failed: $e',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.critical),
                      ),
                    ),
                  ],
                ),
              ),
              data: (result) {
                if (result == null) return const SizedBox.shrink();
                return _AnalysisResultCard(result: result);
              },
            ),
          ],
        );
      },
    );
  }
}

class _ScopeSelector extends ConsumerWidget {
  const _ScopeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(analysisScopeProvider);

    return Wrap(
      spacing: AppSpacing.sm,
      children: AnalysisScope.values.map((scope) {
        final isSelected = scope == selected;
        return ChoiceChip(
          label: Text(scope.label),
          selected: isSelected,
          onSelected: (_) {
            ref.read(analysisScopeProvider.notifier).select(scope);
            ref.read(analysisResultProvider.notifier).clear();
          },
          selectedColor: AppColors.primaryDim,
          backgroundColor: AppColors.surfaceLight,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
          ),
          labelStyle: AppTypography.labelMedium.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        );
      }).toList(),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  final ScopeStats stats;

  const _QuickStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          _ActivityRow(label: 'Drives', value: '${stats.driveCount}'),
          const Divider(color: AppColors.surfaceBorder),
          _ActivityRow(
            label: 'Distance',
            value: '${stats.totalMiles.toStringAsFixed(1)} mi',
          ),
          const Divider(color: AppColors.surfaceBorder),
          _ActivityRow(label: 'Time', value: stats.formattedDuration),
          const Divider(color: AppColors.surfaceBorder),
          _ActivityRow(
            label: 'Avg MPG',
            value: stats.avgMPG > 0 ? stats.avgMPG.toStringAsFixed(1) : '—',
          ),
          if (stats.dateRange.isNotEmpty) ...[
            const Divider(color: AppColors.surfaceBorder),
            _ActivityRow(label: 'Period', value: stats.dateRange),
          ],
        ],
      ),
    );
  }
}

class _AnalyzeButton extends StatelessWidget {
  final bool hasDrives;
  final bool isLoading;
  final VoidCallback onPressed;

  const _AnalyzeButton({
    required this.hasDrives,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: hasDrives && !isLoading ? onPressed : null,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(isLoading ? 'Analyzing...' : 'Analyze'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryDim,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
    );
  }
}

class _AnalysisResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const _AnalysisResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = (result['healthScore'] as num?)?.toInt() ?? 0;
    final summary = result['summary'] as String? ?? '';
    final anomalies = (result['anomalies'] as List<dynamic>?)?.cast<String>() ?? [];
    final recommendations = (result['recommendations'] as List<dynamic>?)?.cast<String>() ?? [];
    final highlights = result['highlights'] as Map<String, dynamic>? ?? {};

    final scoreColor = score >= 80
        ? AppColors.success
        : score >= 60
            ? AppColors.warning
            : AppColors.critical;
    final scoreLabel = score >= 80
        ? 'Excellent'
        : score >= 60
            ? 'Fair'
            : 'Needs Attention';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Health score
        GlassCard(
          glowColor: scoreColor,
          child: Column(
            children: [
              Text('HEALTH SCORE', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 10,
                        backgroundColor: AppColors.gaugeArc,
                        valueColor: AlwaysStoppedAnimation(scoreColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$score', style: AppTypography.dataHuge.copyWith(color: scoreColor, fontSize: 40)),
                        Text('/ 100', style: AppTypography.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(scoreLabel, style: AppTypography.bodyLarge.copyWith(color: scoreColor)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Summary
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.diamond, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('AI Summary', style: AppTypography.displaySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                summary,
                style: AppTypography.aiText.copyWith(fontStyle: FontStyle.normal, height: 1.6),
              ),
            ],
          ),
        ),
        // Anomalies
        if (anomalies.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Anomalies', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          ...anomalies.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _AttentionItem(
                    icon: Icons.warning_amber,
                    color: AppColors.warning,
                    title: 'Anomaly',
                    subtitle: a,
                  ),
                ),
              )),
        ],
        // All Clear badge
        if (score >= 80 && anomalies.isEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            glowColor: AppColors.success,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: const _AttentionItem(
              icon: Icons.check_circle,
              color: AppColors.success,
              title: 'All Clear',
              subtitle: 'No anomalies or concerns detected.',
            ),
          ),
        ],
        // Recommendations
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Recommendations', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          ...recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _AttentionItem(
                    icon: Icons.lightbulb_outline,
                    color: AppColors.dataAccent,
                    title: 'Recommendation',
                    subtitle: r,
                  ),
                ),
              )),
        ],
        // Highlights
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Highlights', padding: EdgeInsets.zero),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            child: Column(
              children: highlights.entries.map((e) {
                final val = e.value?.toString() ?? '—';
                return Column(
                  children: [
                    _ActivityRow(label: e.key, value: val),
                    if (e.key != highlights.keys.last)
                      const Divider(color: AppColors.surfaceBorder),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _AttentionItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _AttentionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.labelMedium.copyWith(color: AppColors.textPrimary)),
              Text(subtitle, style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String label;
  final String value;

  const _ActivityRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium),
          Text(value, style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent)),
        ],
      ),
    );
  }
}

// ─── Predictions Tab ───

class _PredictionsTab extends ConsumerWidget {
  const _PredictionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenanceAsync = ref.watch(maintenanceStreamProvider);
    final uid = ref.watch(userIdProvider);
    final vehicle = ref.watch(activeVehicleProvider);

    return maintenanceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Text('Error loading maintenance: $e', style: AppTypography.bodyMedium),
      ),
      data: (records) {
        // Show AI-predicted and upcoming records
        final predictions = records
            .where((r) => r.isAiPredicted || (r.nextDueDate != null && !r.isCompleted))
            .toList();

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (predictions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60, bottom: AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: AppSpacing.lg),
                    Text('No Predictions Yet', style: AppTypography.displaySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Tap below to request AI analysis of your driving data.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ...predictions.map((record) {
              final isOverdue = record.isOverdue;
              final severity = isOverdue
                  ? 'warning'
                  : record.isCompleted
                      ? 'good'
                      : 'info';
              final icon = _categoryIcon(record.category);
              final timeline = _buildTimeline(record);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _PredictionCard(
                  icon: icon,
                  title: record.title,
                  description: record.description ?? 'AI-predicted maintenance item.',
                  confidence: record.isAiPredicted ? 0.85 : null,
                  timeline: timeline,
                  severity: severity,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.lg),
            // Request AI Prediction button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uid != null && vehicle != null
                    ? () => _requestPrediction(context, ref, uid, vehicle.id)
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Request AI Prediction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _requestPrediction(BuildContext context, WidgetRef ref, String uid, String vehicleId) async {
    try {
      final jobService = ref.read(aiJobServiceProvider);
      await jobService.createMaintenancePredictionJob(uid, vehicleId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI prediction job created. Results will appear shortly.'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create prediction job: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'oil':
      case 'oil change':
        return Icons.oil_barrel;
      case 'filter':
      case 'dpf':
      case 'air filter':
        return Icons.filter_alt;
      case 'coolant':
      case 'cooling':
        return Icons.thermostat;
      case 'transmission':
        return Icons.settings;
      case 'brakes':
        return Icons.disc_full;
      case 'tires':
        return Icons.tire_repair;
      default:
        return Icons.build;
    }
  }

  String _buildTimeline(MaintenanceRecord record) {
    if (record.nextDueDate != null) {
      final diff = record.nextDueDate!.difference(DateTime.now());
      if (diff.isNegative) return 'Overdue';
      if (diff.inDays == 0) return 'Due today';
      if (diff.inDays < 30) return 'In ${diff.inDays} days';
      return DateFormat.yMMMd().format(record.nextDueDate!);
    }
    if (record.nextDueMileage != null) {
      return 'At ${record.nextDueMileage!.toStringAsFixed(0)} mi';
    }
    return 'No timeline';
  }
}

class _PredictionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final double? confidence;
  final String timeline;
  final String severity;

  const _PredictionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.confidence,
    required this.timeline,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final color = severity == 'good'
        ? AppColors.success
        : severity == 'warning'
            ? AppColors.warning
            : AppColors.dataAccent;

    return GlassCard(
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title, style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(description, style: AppTypography.bodyMedium.copyWith(height: 1.5)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (confidence != null) ...[
                _InfoChip(label: 'Confidence', value: '${(confidence! * 100).toInt()}%'),
                const SizedBox(width: AppSpacing.sm),
              ],
              _InfoChip(label: 'Timeline', value: timeline),
            ],
          ),
          if (confidence != null) ...[
            const SizedBox(height: AppSpacing.md),
            // AI badge
            Row(
              children: [
                Icon(Icons.diamond_outlined, size: 10, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'AI PREDICTED',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontSize: 8,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: AppTypography.labelSmall),
          Text(value, style: AppTypography.dataSmall.copyWith(color: AppColors.dataAccent)),
        ],
      ),
    );
  }
}

// ─── Chat Tab ───

class _ChatTab extends StatelessWidget {
  final TextEditingController controller;
  final void Function([String?]) onSend;
  final WidgetRef ref;

  const _ChatTab({required this.controller, required this.onSend, required this.ref});

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatHistoryProvider);
    final isLoading = ref.watch(aiLoadingProvider);

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _buildEmptyChat()
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  itemCount: messages.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (isLoading && index == 0) {
                      return const AiChatBubble(
                        message: '',
                        isUser: false,
                        isLoading: true,
                      );
                    }
                    final msgIndex = isLoading ? index - 1 : index;
                    final msg = messages[messages.length - 1 - msgIndex];
                    return AiChatBubble(
                      message: msg.content,
                      isUser: msg.role == 'user',
                    );
                  },
                ),
        ),
        // Input bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.surfaceBorder),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask about your truck...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.round),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => onSend(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: const Icon(Icons.diamond, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Ask Gemini', style: AppTypography.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Ask anything about your truck. Gemini knows your vehicle, '
              'your drives, and your data.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Suggestion chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip(text: 'Why did my MPG drop?', onTap: () => onSend('Why did my MPG drop?')),
              _SuggestionChip(text: 'Is my EGT safe for towing?', onTap: () => onSend('Is my EGT safe for towing?')),
              _SuggestionChip(text: 'When should I change my oil?', onTap: () => onSend('When should I change my oil?')),
              _SuggestionChip(text: 'Compare last 2 drives', onTap: () => onSend('Compare last 2 drives')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _SuggestionChip({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.round),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}

// ─── Shared Empty State ───

Widget _buildEmptyState({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
