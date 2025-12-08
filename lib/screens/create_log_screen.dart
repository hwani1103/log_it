import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/equipment_alias_service.dart';
import 'work_log_detail_screen.dart';

class CreateLogScreen extends StatefulWidget {
  final DateTime? selectedDate; // 날짜별 조회에서 온 경우 해당 날짜 사용
  final Function(int)? onRequestTabSwitch; // 탭 전환 요청 callback

  const CreateLogScreen({super.key, this.selectedDate, this.onRequestTabSwitch});

  @override
  State<CreateLogScreen> createState() => _CreateLogScreenState();
}

class _CreateLogScreenState extends State<CreateLogScreen> {
  final TextEditingController _equipmentController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final EquipmentAliasService _aliasService = EquipmentAliasService();
  final ImagePicker _picker = ImagePicker();

  final List<File> _mediaFiles = [];
  final List<String> _mediaTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // EquipmentAliasService는 싱글톤이며 main.dart에서 이미 로드됨
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

  String _parseEquipmentName(String input) {
    final trimmed = input.trim().toUpperCase();

    // 패턴 1: 영어2글자 + (하이픈 선택) + 숫자4개 + 알파벳+숫자(선택, 여러개 가능)
    final pattern2Digit = RegExp(r'^([A-Z]{2})-?(\d{4})([A-Z0-9]*)$');
    final match2 = pattern2Digit.firstMatch(trimmed);

    if (match2 != null) {
      var prefix = match2.group(1)!;       // 예: LI
      final numbers = match2.group(2)!;     // 예: 8504
      final suffix = match2.group(3) ?? ''; // 예: A, A1, A2

      // Alias 서비스를 통해 표준 prefix로 변환
      prefix = _aliasService.getStandardPrefix(prefix);

      return '$prefix-$numbers$suffix';    // LIA-8504A
    }

    // 패턴 2: 영어3글자 + (하이픈 선택) + 숫자4개 + 알파벳+숫자(선택, 여러개 가능)
    final pattern3Digit = RegExp(r'^([A-Z]{3})-?(\d{4})([A-Z0-9]*)$');
    final match3 = pattern3Digit.firstMatch(trimmed);

    if (match3 != null) {
      var prefix = match3.group(1)!;
      final numbers = match3.group(2)!;
      final suffix = match3.group(3) ?? '';

      // Alias 서비스를 통해 표준 prefix로 변환
      prefix = _aliasService.getStandardPrefix(prefix);

      return '$prefix-$numbers$suffix';
    }

    // 패턴 3: 영어4글자+ + (하이픈 선택) + 숫자4개 + 알파벳+숫자(선택, 여러개 가능)
    final pattern4Plus = RegExp(r'^([A-Z]{4,})-?(\d{4})([A-Z0-9]*)$');
    final match4 = pattern4Plus.firstMatch(trimmed);

    if (match4 != null) {
      var prefix = match4.group(1)!;
      final numbers = match4.group(2)!;
      final suffix = match4.group(3) ?? '';

      // Alias 서비스를 통해 표준 prefix로 변환
      prefix = _aliasService.getStandardPrefix(prefix);

      return '$prefix-$numbers$suffix';
    }

    // 패턴에 맞지 않으면 그냥 대문자로 반환
    return trimmed;
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
      final List<String> uploadedMediaTypes = [];

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
          uploadedMediaTypes.add(_mediaTypes[i]);
          print('Successfully uploaded file ${i + 1}/${_mediaFiles.length}');
        } catch (uploadError) {
          print('Failed to upload file ${i + 1}: $uploadError');
          throw Exception('${_mediaTypes[i]} 업로드 실패 (${i + 1}/${_mediaFiles.length}): $uploadError');
        }
      }

      // 날짜별 조회에서 온 경우 해당 날짜에 현재 시간 적용, 아니면 현재 시간
      final DateTime createdAt = widget.selectedDate != null
          ? DateTime(
              widget.selectedDate!.year,
              widget.selectedDate!.month,
              widget.selectedDate!.day,
              DateTime.now().hour,
              DateTime.now().minute,
              DateTime.now().second,
            )
          : DateTime.now();

      final workLog = WorkLog(
        id: '',
        userId: userId,
        equipmentName: _parseEquipmentName(_equipmentController.text),
        content: _capitalizeEnglishWords(_contentController.text.trim()),
        createdAt: createdAt,
        mediaUrls: mediaUrls,
        mediaTypes: uploadedMediaTypes,
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

        // 날짜별 조회에서 온 경우 현재 화면을 DetailScreen으로 교체
        if (widget.selectedDate != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkLogDetailScreen(
                workLog: createdWorkLog,
                showEquipmentFirst: false,
              ),
            ),
          );
        } else {
          // 일지작성 탭에서 온 경우 DetailScreen을 push
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkLogDetailScreen(
                workLog: createdWorkLog,
                showEquipmentFirst: false,
                fromCreateTab: true, // 일지작성 탭에서 왔음을 표시
              ),
            ),
          );

          // DetailScreen에서 돌아올 때 날짜별 조회 탭으로 전환 요청
          if (result == 'switchToDateView' && widget.onRequestTabSwitch != null) {
            widget.onRequestTabSwitch!(1); // 인덱스 1 = 날짜별 조회
          }
        }

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
    final content = Padding(
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
                                  final pathParts = _mediaFiles[index].path.split('/');
                                  final fileName = pathParts.isNotEmpty ? pathParts.last : '동영상';
                                  final displayName = fileName.isEmpty
                                      ? '동영상'
                                      : (fileName.length > 12
                                          ? '${fileName.substring(0, 12)}...'
                                          : fileName);
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
                                          displayName,
                                          style: const TextStyle(fontSize: 10),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
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

    // 날짜별 조회에서 온 경우 Scaffold로 감싸기 (SafeArea 적용)
    if (widget.selectedDate != null) {
      return Scaffold(
        body: SafeArea(
          child: content,
        ),
      );
    }

    return content;
  }
}
