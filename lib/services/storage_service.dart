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

      print('Uploading $mediaType: ${file.path}');
      print('File size: ${await file.length()} bytes');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('Upload completed: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Upload Error for $mediaType: $e');
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
