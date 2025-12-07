import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/work_log.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
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
  void initState() {
    super.initState();
    _initializeVideoPlayers();
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeVideoPlayers() {
    for (int i = 0; i < widget.workLog.mediaUrls.length; i++) {
      if (widget.workLog.mediaTypes[i] == 'video') {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.workLog.mediaUrls[i]),
        )..initialize().then((_) {
            if (mounted) setState(() {});
          });
        _videoControllers[i] = controller;
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
    ).then((updated) {
      if (updated == true && mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _showMediaFullScreen(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: widget.workLog.mediaTypes[index] == 'image'
                ? InteractiveViewer(
                    child: CachedNetworkImage(
                      imageUrl: widget.workLog.mediaUrls[index],
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error, color: Colors.white),
                    ),
                  )
                : _videoControllers[index] != null &&
                        _videoControllers[index]!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio:
                            _videoControllers[index]!.value.aspectRatio,
                        child: VideoPlayer(_videoControllers[index]!),
                      )
                    : const CircularProgressIndicator(),
          ),
          floatingActionButton: widget.workLog.mediaTypes[index] == 'video' &&
                  _videoControllers[index] != null
              ? FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      if (_videoControllers[index]!.value.isPlaying) {
                        _videoControllers[index]!.pause();
                      } else {
                        _videoControllers[index]!.play();
                      }
                    });
                  },
                  child: Icon(
                    _videoControllers[index]!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateOnlyStr = DateFormat('yyyy년 MM월 dd일').format(widget.workLog.createdAt);
    final timeStr = DateFormat('HH:mm').format(widget.workLog.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('작업 일지'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 정보 - 설비명만 파란색 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      widget.workLog.equipmentName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // 날짜와 시간 - 검정색 글씨
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateOnlyStr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 작업 내용
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '작업 내용',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.workLog.content.isNotEmpty
                              ? widget.workLog.content
                              : '내용 없음',
                          style: const TextStyle(
                            fontSize: 16,
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
                              return GestureDetector(
                                onTap: () => _showMediaFullScreen(index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: widget.workLog.mediaTypes[index] == 'image'
                                      ? CachedNetworkImage(
                                          imageUrl: widget.workLog.mediaUrls[index],
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.error),
                                          ),
                                        )
                                      : _videoControllers[index] != null &&
                                              _videoControllers[index]!
                                                  .value
                                                  .isInitialized
                                          ? Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                VideoPlayer(_videoControllers[index]!),
                                                const Center(
                                                  child: Icon(
                                                    Icons.play_circle_outline,
                                                    size: 50,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            ),
                                ),
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
          ),

          // 수정하기, 삭제하기 버튼
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _editWorkLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '수정하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deleteWorkLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '삭제하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
