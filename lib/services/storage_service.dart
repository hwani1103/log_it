import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String> uploadMedia(String userId, File file, String mediaType) async {
    try {
      final fileName = '${_uuid.v4()}.${_getFileExtension(file.path)}';
      final ref = _storage.ref().child('users/$userId/$fileName');

      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      print('=== Upload Start ===');
      print('Type: $mediaType');
      print('Path: ${file.path}');
      print('Size: ${fileSizeMB.toStringAsFixed(2)} MB ($fileSize bytes)');
      print('Destination: users/$userId/$fileName');

      // Firebase Storage에 메타데이터와 함께 업로드
      final metadata = SettableMetadata(
        contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'mediaType': mediaType,
        },
      );

      print('Starting upload...');
      final uploadTask = await ref.putFile(file, metadata);

      print('Upload task completed, getting download URL...');
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('=== Upload Success ===');
      print('URL: $downloadUrl');
      print('===================');

      return downloadUrl;
    } catch (e, stackTrace) {
      print('=== Upload Error ===');
      print('Type: $mediaType');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('===================');
      rethrow;
    }
  }

  Future<void> deleteMedia(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('Delete Error: $e');
    }
  }

  String _getFileExtension(String path) {
    return path.split('.').last;
  }
}
