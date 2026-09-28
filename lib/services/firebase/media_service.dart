import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  MediaService({FirebaseStorage? customStorage, ImagePicker? customPicker})
    : _storage = customStorage,
      _picker = customPicker ?? ImagePicker();

  final FirebaseStorage? _storage;
  final ImagePicker _picker;

  FirebaseStorage get _firebaseStorage => _storage ?? FirebaseStorage.instance;

  /// Picks an image from the specified source (camera or gallery) with quality compression.
  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      return file;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Picks a video from the gallery.
  Future<XFile?> pickVideo() async {
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      return file;
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }

  /// Uploads a media file (Image, Video, Voice) to Firebase Storage.
  /// Follows the partitioned structure: users/{senderId}/chats/{conversationId}/{category}/{timestamp}_{filename}
  Future<String?> uploadChatMedia({
    required String filePath,
    required String senderId,
    required String conversationId,
    required String category, // 'images', 'videos', 'voice', 'files'
    required String fileName,
    String? mimeType,
    ValueChanged<double>? onProgress,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not initialized');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath =
          'users/$senderId/chats/$conversationId/$category/${timestamp}_$cleanName';

      final ref = _firebaseStorage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'senderId': senderId,
          'conversationId': conversationId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putFile(file, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((event) {
          if (event.totalBytes > 0) {
            final progress = event.bytesTransferred / event.totalBytes;
            onProgress(progress);
          }
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading media to Firebase Storage: $e');
      rethrow;
    }
  }
}
