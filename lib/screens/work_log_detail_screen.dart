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
import 'edit_log_screen.dart';

class WorkLogDetailScreen extends StatefulWidget {
  final WorkLog workLog;
  final bool showEquipmentFirst; // true: 설비별 조회, false: 날짜별 조회

  const WorkLogDetailScreen({
    super.key,
    required this.workLog,
    this.showEquipmentFirst = false,
  });

  @override
  State<WorkLogDetailScreen> createState() => _WorkLogDetailScreenState();
}

class _WorkLogDetailScreenState extends State<WorkLogDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeVideoPlayer(int index) async {
    if (_videoControllers.containsKey(index)) {
      return; // 이미 초기화됨
    }

    if (index < widget.workLog.mediaTypes.length &&
        widget.workLog.mediaTypes[index] == 'video') {
      try {
        // 캐시에서 동영상 파일 가져오기
        final cacheHelper = VideoCacheHelper();
        final file = await cacheHelper.getCachedVideoFile(widget.workLog.mediaUrls[index]);

        // 캐시된 로컬 파일로 VideoPlayer 초기화
        final controller = VideoPlayerController.file(file)
          ..initialize().then((_) {
            if (mounted) setState(() {});
          });
        _videoControllers[index] = controller;
      } catch (e) {
        print('Failed to initialize video player: $e');
      }
    }
  }

  Future<void> _deleteWorkLog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일지 삭제'),
        content: const Text('이 작업 일지를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 미디어 파일 삭제
        for (final url in widget.workLog.mediaUrls) {
          await _storageService.deleteMedia(url);
        }
        // Firestore 문서 삭제
        await _firestoreService.deleteWorkLog(widget.workLog.id);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일지가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  void _editWorkLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditLogScreen(workLog: widget.workLog),
      ),
    ).then((updatedWorkLog) {
      if (updatedWorkLog != null && mounted) {
        // 현재 디테일 화면을 닫고 수정된 일지의 새 디테일 화면으로 교체
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WorkLogDetailScreen(
              workLog: updatedWorkLog,
              showEquipmentFirst: widget.showEquipmentFirst,
            ),
          ),
        );
      }
    });
  }

  Future<void> _deleteMedia(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('첨부파일 삭제'),
        content: Text('이 ${widget.workLog.mediaTypes[index] == 'image' ? '사진을' : '동영상을'} 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Storage에서 파일 삭제
        await _storageService.deleteMedia(widget.workLog.mediaUrls[index]);

        // 캐시에서도 삭제
        if (widget.workLog.mediaTypes[index] == 'video') {
          final videoCacheHelper = VideoCacheHelper();
          await videoCacheHelper.removeFromCache(widget.workLog.mediaUrls[index]);

          // VideoController도 dispose
          if (_videoControllers.containsKey(index)) {
            _videoControllers[index]?.dispose();
            _videoControllers.remove(index);
          }
        } else if (widget.workLog.mediaTypes[index] == 'image') {
          final imageCacheHelper = CacheHelper();
          await imageCacheHelper.removeImageFromCache(widget.workLog.mediaUrls[index]);
        }

        // 배열에서 제거
        final updatedMediaUrls = List<String>.from(widget.workLog.mediaUrls)..removeAt(index);
        final updatedMediaTypes = List<String>.from(widget.workLog.mediaTypes)..removeAt(index);

        final updatedWorkLog = WorkLog(
          id: widget.workLog.id,
          userId: widget.workLog.userId,
          equipmentName: widget.workLog.equipmentName,
          content: widget.workLog.content,
          createdAt: widget.workLog.createdAt,
          mediaUrls: updatedMediaUrls,
          mediaTypes: updatedMediaTypes,
        );

        // Firestore 업데이트
        await _firestoreService.updateWorkLog(widget.workLog.id, updatedWorkLog);

        if (mounted) {
          // 화면 새로고침
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkLogDetailScreen(
                workLog: updatedWorkLog,
                showEquipmentFirst: widget.showEquipmentFirst,
              ),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('첨부파일이 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }

  void _showMediaFullScreen(int index) async {
    // 동영상인 경우 클릭 시 초기화 (네트워크 사용량 절감)
    if (index < widget.workLog.mediaTypes.length &&
        widget.workLog.mediaTypes[index] == 'video') {
      await _initializeVideoPlayer(index);
    }

    if (!mounted) return;

    final isVideo = index < widget.workLog.mediaTypes.length &&
        widget.workLog.mediaTypes[index] == 'video';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MediaFullScreenView(
          mediaUrl: widget.workLog.mediaUrls[index],
          mediaType: widget.workLog.mediaTypes[index],
          videoController: isVideo ? _videoControllers[index] : null,
        ),
      ),
    );

    // 뒤로가기 후 비디오 일시정지
    if (isVideo && _videoControllers[index] != null) {
      _videoControllers[index]!.pause();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(widget.workLog.createdAt);
    final timeStr = DateFormat('HH:mm').format(widget.workLog.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('작업 일지'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜, 시간, 수정/삭제 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 날짜와 시간
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  // 수정/삭제 버튼
                  Row(
                    children: [
                      TextButton(
                        onPressed: _editWorkLog,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '수정',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: _deleteWorkLog,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '삭제',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 설비명 - 파란 배경
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.blue,
              child: Text(
                widget.workLog.equipmentName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // 작업 내용
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '작업내용',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.workLog.content.isNotEmpty
                        ? widget.workLog.content
                        : '내용 없음',
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // 미디어
            if (widget.workLog.mediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      '첨부 파일',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: widget.workLog.mediaUrls.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTap: () => _showMediaFullScreen(index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (index < widget.workLog.mediaTypes.length &&
                                        widget.workLog.mediaTypes[index] == 'image')
                                    ? FutureBuilder<File>(
                                        future: CacheHelper().getCachedImageFile(widget.workLog.mediaUrls[index]),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasError) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(child: Icon(Icons.error)),
                                            );
                                          }
                                          if (!snapshot.hasData) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(child: CircularProgressIndicator()),
                                            );
                                          }
                                          return Image.file(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: Icon(
                                            Icons.play_circle_outline,
                                            size: 50,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            // X 버튼
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _deleteMedia(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 미디어 풀스크린 뷰 (동영상 재생/일시정지 버튼 상태 관리)
class _MediaFullScreenView extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final VideoPlayerController? videoController;

  const _MediaFullScreenView({
    required this.mediaUrl,
    required this.mediaType,
    this.videoController,
  });

  @override
  State<_MediaFullScreenView> createState() => _MediaFullScreenViewState();
}

class _MediaFullScreenViewState extends State<_MediaFullScreenView> {
  @override
  void initState() {
    super.initState();
    // VideoController에 리스너 추가하여 재생 상태 변경 시 UI 업데이트
    widget.videoController?.addListener(_videoListener);
  }

  @override
  void dispose() {
    widget.videoController?.removeListener(_videoListener);
    super.dispose();
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  void _togglePlayPause() {
    if (widget.videoController == null) return;

    if (widget.videoController!.value.isPlaying) {
      widget.videoController!.pause();
    } else {
      widget.videoController!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: widget.mediaType == 'image'
            ? FutureBuilder<File>(
                future: CacheHelper().getCachedImageFile(widget.mediaUrl),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Icon(Icons.error, color: Colors.white);
                  }
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  return InteractiveViewer(
                    child: Image.file(snapshot.data!),
                  );
                },
              )
            : widget.videoController != null &&
                    widget.videoController!.value.isInitialized
                ? GestureDetector(
                    onTap: _togglePlayPause,
                    child: AspectRatio(
                      aspectRatio: widget.videoController!.value.aspectRatio,
                      child: VideoPlayer(widget.videoController!),
                    ),
                  )
                : const CircularProgressIndicator(),
      ),
      floatingActionButton: widget.mediaType == 'video' &&
              widget.videoController != null &&
              widget.videoController!.value.isInitialized
          ? FloatingActionButton(
              onPressed: _togglePlayPause,
              child: Icon(
                widget.videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
