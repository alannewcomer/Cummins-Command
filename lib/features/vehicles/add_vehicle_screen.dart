import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/vehicle.dart';
import '../../providers/vehicle_provider.dart';
import '../../widgets/common/glass_card.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vinController = TextEditingController();
  final _yearController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _trimController = TextEditingController();
  final _engineController = TextEditingController();
  final _transmissionController = TextEditingController();
  final _odometerController = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _vinController.dispose();
    _yearController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _trimController.dispose();
    _engineController.dispose();
    _transmissionController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final vehicle = Vehicle(
        id: '', // Firestore assigns the ID
        year: _yearController.text.trim(),
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        trim: _trimController.text.trim(),
        vin: _vinController.text.trim().toUpperCase(),
        engine: _engineController.text.trim(),
        transmissionType: _transmissionController.text.trim(),
        currentOdometer: double.tryParse(_odometerController.text) ?? 0,
        isActive: true,
      );

      await ref.read(vehicleRepositoryProvider).addVehicle(vehicle);
      // VIN auto-decode Cloud Function triggers in the background on doc creation.

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not save vehicle. Please try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasExistingVehicles =
        (ref.watch(vehiclesStreamProvider).value?.isNotEmpty) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Add Vehicle', style: AppTypography.displaySmall),
        leading: hasExistingVehicles
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              )
            : null, // No back button on first-time setup
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Header (first-time only) ──
            if (!hasExistingVehicles) ...[
              _SectionHeader(
                icon: Icons.local_shipping,
                title: "Let's set up your truck",
                subtitle:
                    'Your vehicle info helps Gemini give you accurate diagnostics and maintenance advice.',
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // ── VIN (optional) ──
            const SectionHeader(
              title: 'VIN (Optional)',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enter your 17-character VIN for automatic spec lookup.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FormField(
              controller: _vinController,
              label: 'VIN',
              hint: 'e.g. 3C6UR5DL0PG123456',
              maxLength: 17,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                _UpperCaseFormatter(),
              ],
              validator: (v) {
                if (v == null || v.isEmpty) return null; // optional
                if (v.length != 17) return 'VIN must be exactly 17 characters';
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Required ──
            const SectionHeader(
              title: 'Vehicle Info',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _FormField(
                    controller: _yearController,
                    label: 'Year *',
                    hint: '2026',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final year = int.tryParse(v);
                      if (year == null || year < 1980 || year > 2030) {
                        return 'Invalid year';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: _FormField(
                    controller: _makeController,
                    label: 'Make *',
                    hint: 'Ram, Ford, Chevy…',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _FormField(
                    controller: _modelController,
                    label: 'Model *',
                    hint: '2500, F-250, Sierra…',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: _FormField(
                    controller: _trimController,
                    label: 'Trim',
                    hint: 'Laramie, Lariat…',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Engine & Drivetrain (optional) ──
            const SectionHeader(
              title: 'Powertrain (Optional)',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Used to give Gemini accurate engine-specific context.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),

            _FormField(
              controller: _engineController,
              label: 'Engine',
              hint: '6.7L Cummins, 7.3L Power Stroke, L5P Duramax…',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FormField(
              controller: _transmissionController,
              label: 'Transmission',
              hint: 'Aisin AS69RC, TorqShift 10R140…',
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Odometer ──
            const SectionHeader(
              title: 'Odometer (Optional)',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.sm),
            _FormField(
              controller: _odometerController,
              label: 'Current Miles',
              hint: '45000',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Error ──
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.criticalDim,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.critical.withValues(alpha: 0.4)),
                ),
                child: Text(_error!,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.critical)),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Save Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Add Vehicle', style: AppTypography.button),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primaryDim,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Icon(icon, color: AppColors.primary, size: 32),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: AppTypography.displaySmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle,
            style: AppTypography.bodyMedium, textAlign: TextAlign.center),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '', // hide character counter
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
