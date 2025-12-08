import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoCacheHelper {
  static final VideoCacheHelper _instance = VideoCacheHelper._internal();
  factory VideoCacheHelper() => _instance;
  VideoCacheHelper._internal();

  // 동영상 전용 캐시 매니저
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'video_cache',
      stalePeriod: const Duration(days: 30), // 30일간 캐시 유지
      maxNrOfCacheObjects: 100, // 최대 100개 동영상
      repo: JsonCacheInfoRepository(databaseName: 'video_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// 동영상 URL을 캐시된 로컬 파일로 변환
  /// 첫 다운로드: 네트워크에서 다운로드 + 캐시 저장
  /// 이후 사용: 로컬 캐시에서 즉시 로드
  Future<File> getCachedVideoFile(String url) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);

      if (fileInfo != null && fileInfo.file.existsSync()) {
        print('Video loaded from cache: $url');
        return fileInfo.file;
      }

      // 캐시 없음 → 다운로드 + 캐시
      print('Downloading and caching video: $url');
      final file = await _cacheManager.getSingleFile(url);
      print('Video cached successfully');
      return file;
    } catch (e) {
      print('Video cache error: $e');
      rethrow;
    }
  }

  /// 특정 동영상 캐시 삭제
  Future<void> removeFromCache(String url) async {
    await _cacheManager.removeFile(url);
  }

  /// 모든 동영상 캐시 삭제
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// 캐시 크기 확인 (디버깅용)
  Future<void> printCacheInfo() async {
    final cacheInfo = await _cacheManager.getFileFromCache('');
    print('Cache info: $cacheInfo');
  }
}
