import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/memo.dart';
import '../services/auth_service.dart';
import '../services/memo_service.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  final AuthService _authService = AuthService();
  final MemoService _memoService = MemoService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Memo> _memos = [];
  bool _isLoading = true;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMemos() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser?.uid ?? '';
      final memos = await _memoService.getAllMemos(userId);

      // 전체 텍스트 생성 (날짜 + 내용)
      final buffer = StringBuffer();
      for (final memo in memos) {
        final dateStr = DateFormat('M월 d일').format(memo.date);
        buffer.writeln('$dateStr ${'─' * 30}');
        buffer.writeln(memo.content);
        if (memo != memos.last) {
          buffer.writeln();
        }
      }

      setState(() {
        _memos = memos;
        _controller.text = buffer.toString();
        _isLoading = false;
      });
    } catch (e) {
      print('메모 로드 에러: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMemo() async {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        _isEditMode = false;
      });
      return;
    }

    try {
      final userId = _authService.currentUser?.uid ?? '';
      final today = Memo.dateOnly(DateTime.now());

      // 현재 텍스트에서 오늘 메모만 추출
      final lines = _controller.text.split('\n');
      final todayDateStr = DateFormat('M월 d일').format(today);

      // 오늘 날짜 구분선 찾기
      int todayStartIndex = -1;
      int todayEndIndex = lines.length;

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains(todayDateStr) && lines[i].contains('─')) {
          todayStartIndex = i;
        } else if (todayStartIndex != -1 && lines[i].contains('월') && lines[i].contains('일') && lines[i].contains('─')) {
          todayEndIndex = i;
          break;
        }
      }

      String todayContent = '';
      if (todayStartIndex == -1) {
        // 오늘 날짜 구분선이 없으면 전체가 오늘 메모
        todayContent = _controller.text.trim();
      } else {
        // 오늘 날짜 구분선 다음부터 다음 날짜 구분선 전까지
        final contentLines = lines.sublist(todayStartIndex + 1, todayEndIndex);
        todayContent = contentLines.join('\n').trim();
      }

      if (todayContent.isNotEmpty) {
        await _memoService.saveMemo(userId, today, todayContent);
      }

      setState(() {
        _isEditMode = false;
      });

      await _loadMemos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모가 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;

      if (_isEditMode) {
        // 편집 모드로 전환
        final today = DateTime.now();
        final todayDateStr = DateFormat('M월 d일').format(today);

        // 오늘 날짜 구분선이 없으면 추가
        if (!_controller.text.contains(todayDateStr)) {
          final newContent = '$todayDateStr ${'─' * 30}\n${_controller.text}';
          _controller.text = newContent;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: todayDateStr.length + 31), // 날짜 구분선 다음
          );
        } else {
          // 오늘 날짜 구분선 다음으로 커서 이동
          final lines = _controller.text.split('\n');
          int cursorPosition = 0;
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].contains(todayDateStr) && lines[i].contains('─')) {
              cursorPosition = lines.sublist(0, i + 1).join('\n').length + 1;
              break;
            }
          }
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: cursorPosition),
          );
        }

        // 포커스
        Future.delayed(const Duration(milliseconds: 100), () {
          _focusNode.requestFocus();
        });
      } else {
        // 읽기 모드로 전환 (저장)
        _saveMemo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          // 상단 버튼 영역
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: _isEditMode ? Colors.blue : Colors.black87,
                  ),
                  onPressed: _toggleEditMode,
                  tooltip: _isEditMode ? '저장' : '편집',
                ),
              ],
            ),
          ),

          // 메모 영역
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: _isEditMode
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '',
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        _controller.text.isEmpty ? '' : _controller.text,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
