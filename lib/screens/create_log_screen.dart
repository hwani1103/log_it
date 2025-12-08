import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'work_log_detail_screen.dart';

class CreateLogScreen extends StatefulWidget {
  const CreateLogScreen({super.key});

  @override
  State<CreateLogScreen> createState() => _CreateLogScreenState();
}

class _CreateLogScreenState extends State<CreateLogScreen> {
  final TextEditingController _equipmentController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  final List<File> _mediaFiles = [];
  final List<String> _mediaTypes = [];
  bool _isLoading = false;

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
        _mediaFiles.add(File(image.path));
        _mediaTypes.add('image');
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // 5분 제한
      );
      if (video != null) {
        final file = File(video.path);
        final fileSize = await file.length();
        final fileSizeMB = fileSize / (1024 * 1024);

        print('Selected video: ${video.path}');
        print('Video size: ${fileSizeMB.toStringAsFixed(2)} MB');

        // 100MB 제한
        if (fileSizeMB > 100) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('동영상 크기가 너무 큽니다 (${fileSizeMB.toStringAsFixed(1)}MB). 100MB 이하로 선택해주세요.')),
            );
          }
          return;
        }

        setState(() {
          _mediaFiles.add(file);
          _mediaTypes.add('video');
        });
      }
    } catch (e) {
      print('Video selection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동영상 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _mediaFiles.add(File(photo.path));
        _mediaTypes.add('image');
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

  Future<void> _saveWorkLog() async {
    if (_equipmentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설비명을 입력하세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser!.uid;
      final List<String> mediaUrls = [];

      // 미디어 업로드
      for (int i = 0; i < _mediaFiles.length; i++) {
        print('Uploading file ${i + 1}/${_mediaFiles.length}: ${_mediaTypes[i]}');

        try {
          final url = await _storageService.uploadMedia(
            userId,
            _mediaFiles[i],
            _mediaTypes[i],
          );
          mediaUrls.add(url);
          print('Successfully uploaded file ${i + 1}/${_mediaFiles.length}');
        } catch (uploadError) {
          print('Failed to upload file ${i + 1}: $uploadError');
          throw Exception('${_mediaTypes[i]} 업로드 실패 (${i + 1}/${_mediaFiles.length}): $uploadError');
        }
      }

      final workLog = WorkLog(
        id: '',
        userId: userId,
        equipmentName: _equipmentController.text.trim().toUpperCase(),
        content: _capitalizeEnglishWords(_contentController.text.trim()),
        createdAt: DateTime.now(),
        mediaUrls: mediaUrls,
        mediaTypes: _mediaTypes,
      );

      final createdWorkLog = await _firestoreService.createWorkLog(workLog);

      if (mounted) {
        // 입력 필드 초기화
        _equipmentController.clear();
        _contentController.clear();
        setState(() {
          _mediaFiles.clear();
          _mediaTypes.clear();
        });

        // 디테일 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkLogDetailScreen(
              workLog: createdWorkLog,
              showEquipmentFirst: false,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일지가 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
    return Padding(
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
          if (_mediaFiles.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mediaFiles.length,
                itemBuilder: (context, index) {
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
                        child: _mediaTypes[index] == 'image'
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(_mediaFiles[index], fit: BoxFit.cover),
                              )
                            : FutureBuilder<int>(
                                future: _mediaFiles[index].length(),
                                builder: (context, snapshot) {
                                  final fileName = _mediaFiles[index].path.split('/').last;
                                  final fileSize = snapshot.hasData
                                      ? (snapshot.data! / (1024 * 1024)).toStringAsFixed(1)
                                      : '...';
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.videocam, size: 30, color: Colors.blue),
                                        const SizedBox(height: 4),
                                        Text(
                                          fileName.length > 12
                                              ? '${fileName.substring(0, 12)}...'
                                              : fileName,
                                          style: const TextStyle(fontSize: 10),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$fileSize MB',
                                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Positioned(
                        top: 0,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _mediaFiles.removeAt(index);
                              _mediaTypes.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ],
                  );
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
            onPressed: _isLoading ? null : _saveWorkLog,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('저장', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
