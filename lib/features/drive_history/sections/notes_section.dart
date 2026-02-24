import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../config/constants.dart';
import '../../../models/drive_session.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../widgets/common/glass_card.dart';

class NotesSection extends ConsumerWidget {
  final DriveSession drive;

  const NotesSection({super.key, required this.drive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNotes = drive.notes != null && drive.notes!.isNotEmpty;
    final hasCargo = drive.cargoDescription != null &&
        drive.cargoDescription!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GlassCard(
        onTap: () => _showEditSheet(context, ref),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_alt_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Notes & Cargo',
                  style: AppTypography.labelMedium,
                ),
                const Spacer(),
                Icon(Icons.edit_outlined,
                    size: 14, color: AppColors.textTertiary),
              ],
            ),
            if (hasNotes || hasCargo) ...[
              const SizedBox(height: AppSpacing.md),
              if (hasNotes)
                Text(
                  drive.notes!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              if (hasCargo) ...[
                if (hasNotes) const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        drive.cargoDescription!,
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (drive.cargoWeightLbs != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDim,
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          '${drive.cargoWeightLbs!.toStringAsFixed(0)} lbs',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap to add notes or cargo info',
                style: AppTypography.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    final notesController = TextEditingController(text: drive.notes ?? '');
    final cargoController =
        TextEditingController(text: drive.cargoDescription ?? '');
    final weightController = TextEditingController(
      text: drive.cargoWeightLbs?.toStringAsFixed(0) ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xxl,
            right: AppSpacing.xxl,
            top: AppSpacing.xxl,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
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
              Text('Notes & Cargo', style: AppTypography.displaySmall),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Drive notes...',
                  labelText: 'Notes',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: cargoController,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. 10K lb boat trailer',
                  labelText: 'Cargo Description',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Weight in lbs',
                  labelText: 'Cargo Weight (lbs)',
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _save(ref, notesController.text, cargoController.text,
                        weightController.text);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save(WidgetRef ref, String notes, String cargo, String weight) {
    final uid = ref.read(userIdProvider);
    final vehicle = ref.read(activeVehicleProvider);
    if (uid == null || vehicle == null) return;

    final updates = <String, dynamic>{
      'notes': notes.isEmpty ? null : notes,
      'cargoDescription': cargo.isEmpty ? null : cargo,
      'cargoWeightLbs': weight.isEmpty ? null : double.tryParse(weight),
    };

    FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(vehicle.id)
        .collection(AppConstants.drivesSubcollection)
        .doc(drive.id)
        .update(updates);
  }
}
