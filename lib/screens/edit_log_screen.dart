import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class EditLogScreen extends StatefulWidget {
  final WorkLog workLog;

  const EditLogScreen({super.key, required this.workLog});

  @override
  State<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends State<EditLogScreen> {
  late TextEditingController _equipmentController;
  late TextEditingController _contentController;
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  // 기존 미디어
  List<String> _existingMediaUrls = [];
  List<String> _existingMediaTypes = [];

  // 새로 추가한 미디어
  final List<File> _newMediaFiles = [];
  final List<String> _newMediaTypes = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _equipmentController = TextEditingController(text: widget.workLog.equipmentName);
    _contentController = TextEditingController(text: widget.workLog.content);
    _existingMediaUrls = List.from(widget.workLog.mediaUrls);
    _existingMediaTypes = List.from(widget.workLog.mediaTypes);
  }

  @override
  void dispose() {
    _equipmentController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newMediaFiles.add(File(image.path));
        _newMediaTypes.add('image');
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _newMediaFiles.add(File(video.path));
        _newMediaTypes.add('video');
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _newMediaFiles.add(File(photo.path));
        _newMediaTypes.add('image');
      });
    }
  }

  String _capitalizeEnglishWords(String text) {
    // 띄어쓰기, 구두점(., /, !, ?, - 등) 뒤의 영어 소문자를 대문자로 변환
    return text.replaceAllMapped(
      RegExp(r'(^|[\s.,/!?-])([a-z])'),
      (match) => match.group(1)! + match.group(2)!.toUpperCase(),
    );
  }

  Future<void> _updateWorkLog() async {
    if (_equipmentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설비명을 입력하세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser!.uid;

      // 새로운 미디어 파일 업로드
      final List<String> newMediaUrls = [];
      for (int i = 0; i < _newMediaFiles.length; i++) {
        final url = await _storageService.uploadMedia(
          userId,
          _newMediaFiles[i],
          _newMediaTypes[i],
        );
        newMediaUrls.add(url);
      }

      // 기존 미디어 + 새로 업로드된 미디어 결합
      final allMediaUrls = [..._existingMediaUrls, ...newMediaUrls];
      final allMediaTypes = [..._existingMediaTypes, ..._newMediaTypes];

      final updatedWorkLog = WorkLog(
        id: widget.workLog.id,
        userId: userId,
        equipmentName: _equipmentController.text.trim().toUpperCase(),
        content: _capitalizeEnglishWords(_contentController.text.trim()),
        createdAt: widget.workLog.createdAt,
        mediaUrls: allMediaUrls,
        mediaTypes: allMediaTypes,
      );

      await _firestoreService.updateWorkLog(widget.workLog.id, updatedWorkLog);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일지가 수정되었습니다')),
        );
        Navigator.pop(context, updatedWorkLog); // 수정된 WorkLog를 반환
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeExistingMedia(int index) async {
    final url = _existingMediaUrls[index];

    try {
      // Storage에서 파일 삭제
      await _storageService.deleteMedia(url);

      setState(() {
        _existingMediaUrls.removeAt(index);
        _existingMediaTypes.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 삭제 실패: $e')),
        );
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('사진 촬영'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 사진 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('갤러리에서 동영상 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일지 수정'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _equipmentController,
                decoration: const InputDecoration(
                  labelText: '설비명',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: '작업 내용',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                ),
              ),
              const SizedBox(height: 16),

              // 기존 미디어 + 새로 추가한 미디어 표시
              if (_existingMediaUrls.isNotEmpty || _newMediaFiles.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingMediaUrls.length + _newMediaFiles.length,
                    itemBuilder: (context, index) {
                      final isExisting = index < _existingMediaUrls.length;

                      if (isExisting) {
                        // 기존 미디어 (URL에서 로드)
                        final mediaUrl = _existingMediaUrls[index];
                        final mediaType = _existingMediaTypes[index];

                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: mediaType == 'image'
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: mediaUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.videocam, size: 40),
                                    ),
                            ),
                            Positioned(
                              top: 0,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _removeExistingMedia(index),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // 새로 추가한 미디어 (로컬 파일)
                        final newIndex = index - _existingMediaUrls.length;
                        final mediaFile = _newMediaFiles[newIndex];
                        final mediaType = _newMediaTypes[newIndex];

                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: mediaType == 'image'
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(mediaFile, fit: BoxFit.cover),
                                    )
                                  : const Center(
                                      child: Icon(Icons.videocam, size: 40),
                                    ),
                            ),
                            Positioned(
                              top: 0,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _newMediaFiles.removeAt(newIndex);
                                    _newMediaTypes.removeAt(newIndex);
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _showMediaOptions,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('사진/동영상 추가'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateWorkLog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('수정 완료', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
