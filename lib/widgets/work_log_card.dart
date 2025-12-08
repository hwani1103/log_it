import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/work_log.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/cache_helper.dart';
import '../utils/video_cache_helper.dart';

class WorkLogCard extends StatelessWidget {
  final WorkLog workLog;
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  WorkLogCard({super.key, required this.workLog});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    workLog.equipmentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(workLog.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (workLog.content.isNotEmpty)
              Text(
                workLog.content,
                style: const TextStyle(fontSize: 14),
              ),
            if (workLog.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: workLog.mediaUrls.length,
                  itemBuilder: (context, index) {
                    final url = workLog.mediaUrls[index];
                    final type = workLog.mediaTypes[index];

                    return GestureDetector(
                      onTap: () {
                        _showMediaFullScreen(context, url, type);
                      },
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: type == 'image'
                            ? CachedNetworkImage(
                                imageUrl: url,
                                cacheKey: CacheHelper.getStableCacheKey(url),
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    cacheKey: CacheHelper.getStableCacheKey(url),
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        Container(color: Colors.grey.shade200),
                                  ),
                                  const Icon(
                                    Icons.play_circle_outline,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일지 삭제'),
        content: const Text('이 일지를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      await _deleteWorkLog(context);
    }
  }

  Future<void> _deleteWorkLog(BuildContext context) async {
    try {
      // Storage에서 미디어 파일 삭제
      for (final url in workLog.mediaUrls) {
        await _storageService.deleteMedia(url);
      }

      // Firestore에서 일지 삭제
      await _firestoreService.deleteWorkLog(workLog.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일지가 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  void _showMediaFullScreen(BuildContext context, String url, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: type == 'image'
                ? InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      cacheKey: CacheHelper.getStableCacheKey(url),
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error, color: Colors.white),
                    ),
                  )
                : VideoPlayerWidget(url: url),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;

  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // 캐시에서 동영상 파일 가져오기 (없으면 다운로드)
      final cacheHelper = VideoCacheHelper();
      final file = await cacheHelper.getCachedVideoFile(widget.url);

      // 캐시된 로컬 파일로 VideoPlayer 초기화
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isLoading = false);
            _controller!.play();
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _error = error.toString();
              _isLoading = false;
            });
          }
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(height: 8),
            Text('동영상 로드 실패', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_isLoading || _controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
