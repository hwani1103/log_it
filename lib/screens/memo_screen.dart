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

  List<Memo> _allMemos = [];
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

      setState(() {
        _allMemos = memos;
        _isLoading = false;
      });
    } catch (e) {
      print('메모 로드 에러: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMemo() async {
    try {
      final userId = _authService.currentUser?.uid ?? '';
      final today = Memo.dateOnly(DateTime.now());
      final content = _controller.text.trim();

      if (content.isNotEmpty) {
        await _memoService.saveMemo(userId, today, content);
      }

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

  void _toggleEditMode() async {
    if (_isEditMode) {
      // 편집 모드 → 읽기 모드: 저장
      final savedContent = _controller.text.trim();
      await _saveMemo();

      // 저장 후 로컬 상태 업데이트 (네트워크 실패해도 UI에는 반영)
      if (savedContent.isNotEmpty) {
        final userId = _authService.currentUser?.uid ?? '';
        final today = Memo.dateOnly(DateTime.now());
        final now = DateTime.now();

        // 기존 메모에서 오늘 메모 찾기
        final existingIndex = _allMemos.indexWhere((m) =>
          m.date.year == today.year &&
          m.date.month == today.month &&
          m.date.day == today.day
        );

        final newMemo = Memo(
          id: existingIndex >= 0 ? _allMemos[existingIndex].id : '',
          userId: userId,
          date: today,
          content: savedContent,
          createdAt: existingIndex >= 0 ? _allMemos[existingIndex].createdAt : now,
          updatedAt: now,
        );

        setState(() {
          if (existingIndex >= 0) {
            _allMemos[existingIndex] = newMemo;
          } else {
            _allMemos.insert(0, newMemo);
          }
          _isEditMode = false;
        });
      } else {
        setState(() {
          _isEditMode = false;
        });
      }
    } else {
      // 읽기 모드 → 편집 모드: 오늘 메모만 로드
      try {
        final userId = _authService.currentUser?.uid ?? '';
        final today = Memo.dateOnly(DateTime.now());

        // 로컬에서 먼저 찾기
        final localMemo = _allMemos.firstWhere(
          (m) => m.date.year == today.year &&
                 m.date.month == today.month &&
                 m.date.day == today.day,
          orElse: () => Memo(
            id: '',
            userId: userId,
            date: today,
            content: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        setState(() {
          _isEditMode = true;
          _controller.text = localMemo.content;
        });

        // 커서를 맨 끝으로
        Future.delayed(const Duration(milliseconds: 100), () {
          _focusNode.requestFocus();
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      } catch (e) {
        print('편집 모드 전환 에러: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('편집 모드 전환 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 버튼 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: _isEditMode ? Colors.red : Colors.black87,
                    ),
                    onPressed: _toggleEditMode,
                    tooltip: _isEditMode ? '저장' : '편집',
                  ),
                ],
              ),
            ),

            // 메모 영역
            Expanded(
              child: _isEditMode
                  ? _buildEditMode()
                  : _buildReadMode(),
            ),
          ],
        ),
      ),
    );
  }

  // 편집 모드: 오늘 메모만 편집
  Widget _buildEditMode() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
        ),
        textAlignVertical: TextAlignVertical.top,
      ),
    );
  }

  // 읽기 모드: 모든 메모를 날짜 구분선과 함께 표시
  Widget _buildReadMode() {
    if (_allMemos.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _allMemos.map((memo) {
          final dateStr = DateFormat('M월 d일').format(memo.date);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 구분선
                Text(
                  '$dateStr ${'─' * 30}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // 메모 내용
                Text(
                  memo.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
