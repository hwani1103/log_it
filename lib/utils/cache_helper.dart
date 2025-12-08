import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheHelper {
  static final CacheHelper _instance = CacheHelper._internal();
  factory CacheHelper() => _instance;
  CacheHelper._internal();

  // 이미지 전용 캐시 매니저
  static final CacheManager _imageCacheManager = CacheManager(
    Config(
      'image_cache',
      stalePeriod: const Duration(days: 30), // 30일간 캐시 유지
      maxNrOfCacheObjects: 500, // 최대 500개 이미지
      repo: JsonCacheInfoRepository(databaseName: 'image_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// Extracts a stable cache key from Firebase Storage URLs
  /// Firebase Storage URLs have tokens that can change, breaking cache
  /// Example: https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Ffile.jpg?alt=media&token=xxxxx
  /// We extract the path portion (everything before the '?' or '&token=') as the stable key
  static String getStableCacheKey(String url) {
    try {
      final uri = Uri.parse(url);

      // For Firebase Storage URLs, use the path + encoded path parameter as the key
      if (uri.host.contains('firebasestorage.googleapis.com')) {
        // Remove query parameters that contain tokens
        return '${uri.host}${uri.path}';
      }

      // For other URLs, use the full URL without query parameters
      return uri.origin + uri.path;
    } catch (e) {
      // If parsing fails, return the original URL
      return url;
    }
  }

  /// 이미지 URL을 캐시된 로컬 파일로 변환
  /// 첫 다운로드: 네트워크에서 다운로드 + 캐시 저장
  /// 이후 사용: 로컬 캐시에서 즉시 로드
  Future<File> getCachedImageFile(String url) async {
    try {
      // 안정적인 캐시 키 생성
      final cacheKey = getStableCacheKey(url);

      final fileInfo = await _imageCacheManager.getFileFromCache(cacheKey);

      if (fileInfo != null && fileInfo.file.existsSync()) {
        print('Image loaded from cache: $cacheKey');
        return fileInfo.file;
      }

      // 캐시 없음 → 다운로드 + 캐시 (cacheKey 사용)
      print('Downloading and caching image: $cacheKey');
      final file = await _imageCacheManager.getSingleFile(
        url,
        key: cacheKey, // 안정적인 키로 캐시
      );
      print('Image cached successfully');
      return file;
    } catch (e) {
      print('Image cache error: $e');
      rethrow;
    }
  }

  /// 특정 이미지 캐시 삭제
  Future<void> removeImageFromCache(String url) async {
    final cacheKey = getStableCacheKey(url);
    await _imageCacheManager.removeFile(cacheKey);
  }

  /// 모든 이미지 캐시 삭제
  Future<void> clearImageCache() async {
    await _imageCacheManager.emptyCache();
  }
}
