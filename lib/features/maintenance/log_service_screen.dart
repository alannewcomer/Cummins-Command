import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../config/maintenance_templates.dart';
import '../../models/maintenance_record.dart';
import '../../providers/maintenance_provider.dart';
import '../../providers/vehicle_provider.dart';

class LogServiceScreen extends ConsumerStatefulWidget {
  final String? preselectedServiceTypeId;

  const LogServiceScreen({super.key, this.preselectedServiceTypeId});

  @override
  ConsumerState<LogServiceScreen> createState() => _LogServiceScreenState();
}

class _LogServiceScreenState extends ConsumerState<LogServiceScreen> {
  String? _selectedServiceTypeId;
  final _titleController = TextEditingController();
  final _costController = TextEditingController();
  final _odometerController = TextEditingController();
  final _notesController = TextEditingController();
  final _partsController = TextEditingController();
  final _hoursController = TextEditingController();
  DateTime _date = DateTime.now();
  String _provider = 'DIY';
  bool _saving = false;

  static const _providers = ['DIY', 'Dealer', 'Shop'];

  @override
  void initState() {
    super.initState();
    _selectedServiceTypeId = widget.preselectedServiceTypeId;

    // Pre-fill title from template
    if (_selectedServiceTypeId != null) {
      final template = getServiceType(_selectedServiceTypeId!);
      if (template != null) {
        _titleController.text = template.name;
      }
    }

    // Pre-fill odometer and engine hours from vehicle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vehicle = ref.read(activeVehicleProvider);
      if (vehicle != null && vehicle.currentOdometer > 0) {
        _odometerController.text = vehicle.currentOdometer.round().toString();
      }
      if (vehicle != null && (vehicle.currentEngineHours ?? 0) > 0) {
        _hoursController.text = vehicle.currentEngineHours!.round().toString();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    _odometerController.dispose();
    _notesController.dispose();
    _partsController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Group service types by category for the selector
    final groupedTypes = <String, List<ServiceTypeTemplate>>{};
    for (final t in kServiceTypes) {
      groupedTypes.putIfAbsent(t.category, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Log Service', style: AppTypography.displaySmall),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // Service Type Selector
          Text('Service Type',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _selectedServiceTypeId,
            dropdownColor: AppColors.surface,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Select service type',
            ),
            items: [
              for (final entry in groupedTypes.entries) ...[
                DropdownMenuItem<String>(
                  enabled: false,
                  value: '__header_${entry.key}',
                  child: Text(entry.key,
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
                ...entry.value.map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Row(
                        children: [
                          Icon(t.icon, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(t.name),
                        ],
                      ),
                    )),
              ],
            ],
            onChanged: (val) {
              if (val != null && !val.startsWith('__header_')) {
                setState(() {
                  _selectedServiceTypeId = val;
                  final template = getServiceType(val);
                  if (template != null &&
                      _titleController.text.isEmpty) {
                    _titleController.text = template.name;
                  }
                });
              }
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // Title
          TextField(
            controller: _titleController,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Description'),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Date picker
          Text('Date',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border:
                    Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    DateFormat('MMM d, yyyy').format(_date),
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Odometer + Hours + Cost
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _odometerController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textPrimary),
                  decoration:
                      const InputDecoration(labelText: 'Odometer (mi)'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textPrimary),
                  decoration:
                      const InputDecoration(labelText: 'Engine Hours'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Cost
          TextField(
            controller: _costController,
            keyboardType: TextInputType.number,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(
                labelText: 'Cost', prefixText: '\$ '),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Service Provider
          Text('Service Provider',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _providers.map((p) {
              final selected = _provider == p;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(p,
                      style: AppTypography.labelMedium.copyWith(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      )),
                  selected: selected,
                  onSelected: (_) => setState(() => _provider = p),
                  selectedColor: AppColors.primaryDim,
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Parts used
          TextField(
            controller: _partsController,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Parts Used (comma separated)',
              hintText: 'e.g., Fleetguard LF14000NN, Fleetguard FS53000',
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Notes
          TextField(
            controller: _notesController,
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Service Record'),
            ),
          ),

          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() => _saving = true);

    final template = _selectedServiceTypeId != null
        ? getServiceType(_selectedServiceTypeId!)
        : null;
    final category = template?.name ?? title;
    final odometer = double.tryParse(_odometerController.text);
    final engineHours = double.tryParse(_hoursController.text);
    final cost = double.tryParse(_costController.text);
    final parts = _partsController.text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final record = MaintenanceRecord(
      id: '',
      vehicleId: '',
      category: category,
      title: title,
      description:
          _notesController.text.isEmpty ? null : _notesController.text,
      date: _date,
      cost: cost,
      odometerReading: odometer,
      isCompleted: true,
      serviceTypeId: _selectedServiceTypeId,
      source: 'scheduled',
      serviceProvider: _provider,
      partsUsed: parts,
    );

    await ref.read(maintenanceRepositoryProvider).logServiceAndUpdateSchedule(
          record: record,
          serviceTypeId: _selectedServiceTypeId,
          odometerReading: odometer,
          engineHours: engineHours,
        );

    if (mounted) {
      setState(() => _saving = false);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service record saved')),
      );
    }
  }
}
