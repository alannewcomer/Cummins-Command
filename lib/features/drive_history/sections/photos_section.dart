import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../models/drive_session.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../services/photo_service.dart';

class PhotosSection extends ConsumerStatefulWidget {
  final DriveSession drive;

  const PhotosSection({super.key, required this.drive});

  @override
  ConsumerState<PhotosSection> createState() => _PhotosSectionState();
}

class _PhotosSectionState extends ConsumerState<PhotosSection> {
  final _photoService = PhotoService();
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final photos = widget.drive.photoUrls;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Photos', style: AppTypography.labelMedium),
              if (_uploading) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + 1,
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return _AddPhotoButton(onTap: () => _showPickerSheet());
                }
                return _PhotoThumbnail(
                  url: photos[index],
                  onTap: () => _showFullScreen(context, photos, index),
                  onLongPress: () =>
                      _confirmDelete(context, photos[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ListTile(
                  leading: Icon(Icons.camera_alt,
                      color: AppColors.primary),
                  title: Text('Camera',
                      style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUpload(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library,
                      color: AppColors.dataAccent),
                  title: Text('Gallery',
                      style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUpload(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final uid = ref.read(userIdProvider);
    final vehicle = ref.read(activeVehicleProvider);
    if (uid == null || vehicle == null) return;

    final file = await _photoService.pickPhoto(source: source);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final url = await _photoService.uploadDrivePhoto(
        uid,
        vehicle.id,
        widget.drive.id,
        file,
      );
      await _photoService.addPhotoToDrive(
        uid,
        vehicle.id,
        widget.drive.id,
        url,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _confirmDelete(BuildContext context, String url) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePhoto(url);
            },
            child: Text('Delete',
                style: TextStyle(color: AppColors.critical)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePhoto(String url) async {
    final uid = ref.read(userIdProvider);
    final vehicle = ref.read(activeVehicleProvider);
    if (uid == null || vehicle == null) return;

    try {
      await _photoService.deleteDrivePhoto(url);
      await _photoService.removePhotoFromDrive(
        uid,
        vehicle.id,
        widget.drive.id,
        url,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _showFullScreen(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(
          urls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoThumbnail({
    required this.url,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.surfaceLight,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceLight,
                child: Icon(Icons.broken_image,
                    size: 24, color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Icon(Icons.add_a_photo,
            size: 24, color: AppColors.textTertiary),
      ),
    );
  }
}

class _FullScreenViewer extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;

  const _FullScreenViewer({
    required this.urls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                urls[index],
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
