import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/config/constants.dart';
import 'package:uuid/uuid.dart';

class PhotoService {
  final _picker = ImagePicker();
  static const _maxWidth = 1920.0;
  static const _jpegQuality = 85;

  /// Pick a photo from camera or gallery.
  Future<File?> pickPhoto({required ImageSource source}) async {
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: _maxWidth,
      imageQuality: _jpegQuality,
    );
    if (xfile == null) return null;
    return File(xfile.path);
  }

  /// Upload a photo to Firebase Storage and return the download URL.
  Future<String> uploadDrivePhoto(
    String userId,
    String vehicleId,
    String driveId,
    File photo,
  ) async {
    final photoId = const Uuid().v4();
    final storagePath =
        'drives/$userId/$vehicleId/$driveId/photos/$photoId.jpg';
    final ref = FirebaseStorage.instance.ref(storagePath);

    await ref.putFile(
      photo,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await ref.getDownloadURL();
  }

  /// Delete a photo from Firebase Storage by its download URL.
  Future<void> deleteDrivePhoto(String photoUrl) async {
    final ref = FirebaseStorage.instance.refFromURL(photoUrl);
    await ref.delete();
  }

  /// Add a photo URL to a drive document's photoUrls array.
  Future<void> addPhotoToDrive(
    String userId,
    String vehicleId,
    String driveId,
    String photoUrl,
  ) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(vehicleId)
        .collection(AppConstants.drivesSubcollection)
        .doc(driveId)
        .update({
      'photoUrls': FieldValue.arrayUnion([photoUrl]),
    });
  }

  /// Remove a photo URL from a drive document's photoUrls array.
  Future<void> removePhotoFromDrive(
    String userId,
    String vehicleId,
    String driveId,
    String photoUrl,
  ) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.vehiclesSubcollection)
        .doc(vehicleId)
        .collection(AppConstants.drivesSubcollection)
        .doc(driveId)
        .update({
      'photoUrls': FieldValue.arrayRemove([photoUrl]),
    });
  }
}
