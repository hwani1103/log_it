class CacheHelper {
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
}
