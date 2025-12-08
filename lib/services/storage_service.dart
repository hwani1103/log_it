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

      print('=============== 네트워크 요청!! ===============');
      print('📤 [Storage] 파일 업로드 시작');
      print('타입: $mediaType');
      print('크기: ${fileSizeMB.toStringAsFixed(2)} MB');
      print('경로: users/$userId/$fileName');
      print('===========================================');

      // Firebase Storage에 메타데이터와 함께 업로드
      final metadata = SettableMetadata(
        contentType: mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
          'mediaType': mediaType,
        },
      );

      final uploadTask = await ref.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('✅ [Storage] 업로드 완료 (${fileSizeMB.toStringAsFixed(2)} MB)');

      return downloadUrl;
    } catch (e, stackTrace) {
      print('❌ [Storage] 업로드 실패');
      print('타입: $mediaType');
      print('에러: $e');
      print('===========================================');
      rethrow;
    }
  }

  Future<void> deleteMedia(String url) async {
    try {
      print('=============== 네트워크 요청!! ===============');
      print('🗑️ [Storage] 파일 삭제');
      print('URL: $url');
      print('===========================================');

      final ref = _storage.refFromURL(url);
      await ref.delete();

      print('✅ [Storage] 파일 삭제 완료');
    } catch (e) {
      print('❌ [Storage] 삭제 실패: $e');
      print('===========================================');
    }
  }

  String _getFileExtension(String path) {
    return path.split('.').last;
  }
}
