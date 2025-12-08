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
  DateTime? _selectedDate; // 읽기 모드에서 선택된 날짜 (수정/삭제 버튼 표시용)
  DateTime? _editingDate; // 편집 모드에서 편집 중인 날짜

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
      final dateToSave = _editingDate ?? Memo.dateOnly(DateTime.now());
      final content = _controller.text.trim();

      if (content.isNotEmpty) {
        await _memoService.saveMemo(userId, dateToSave, content);
      }

      // 에러 무시하고 계속 진행 (로컬 상태로 작동)
      try {
        await _loadMemos();
      } catch (e) {
        print('메모 로드 에러 (무시): $e');
      }

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

  Future<void> _deleteMemo(DateTime date) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메모 삭제'),
        content: Text('${DateFormat('M월 d일').format(date)} 메모를 삭제하시겠습니까?'),
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

    if (confirmed != true) return;

    try {
      // 로컬에서 찾기
      final memoToDelete = _allMemos.firstWhere(
        (m) => m.date.year == date.year &&
               m.date.month == date.month &&
               m.date.day == date.day,
      );

      // Firebase에서 삭제
      if (memoToDelete.id.isNotEmpty) {
        await _memoService.deleteMemo(memoToDelete.id);
      }

      // 로컬 상태 업데이트
      setState(() {
        _allMemos.removeWhere((m) =>
          m.date.year == date.year &&
          m.date.month == date.month &&
          m.date.day == date.day
        );
        _selectedDate = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모가 삭제되었습니다')),
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

  void _toggleEditMode([DateTime? dateToEdit]) async {
    if (_isEditMode) {
      // 편집 모드 → 읽기 모드: 저장
      final savedContent = _controller.text.trim();
      await _saveMemo();

      // 저장 후 로컬 상태 업데이트 (네트워크 실패해도 UI에는 반영)
      if (savedContent.isNotEmpty) {
        final userId = _authService.currentUser?.uid ?? '';
        final dateToSave = _editingDate ?? Memo.dateOnly(DateTime.now());
        final now = DateTime.now();

        // 기존 메모에서 해당 날짜 메모 찾기
        final existingIndex = _allMemos.indexWhere((m) =>
          m.date.year == dateToSave.year &&
          m.date.month == dateToSave.month &&
          m.date.day == dateToSave.day
        );

        final newMemo = Memo(
          id: existingIndex >= 0 ? _allMemos[existingIndex].id : '',
          userId: userId,
          date: dateToSave,
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
          _editingDate = null;
          _selectedDate = null;
        });
      } else {
        setState(() {
          _isEditMode = false;
          _editingDate = null;
          _selectedDate = null;
        });
      }
    } else {
      // 읽기 모드 → 편집 모드
      try {
        final userId = _authService.currentUser?.uid ?? '';
        final targetDate = dateToEdit ?? Memo.dateOnly(DateTime.now());

        // 로컬에서 먼저 찾기
        final localMemo = _allMemos.firstWhere(
          (m) => m.date.year == targetDate.year &&
                 m.date.month == targetDate.month &&
                 m.date.day == targetDate.day,
          orElse: () => Memo(
            id: '',
            userId: userId,
            date: targetDate,
            content: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        setState(() {
          _isEditMode = true;
          _editingDate = targetDate;
          _selectedDate = null;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _allMemos.map((memo) {
          final dateStr = DateFormat('M월 d일').format(memo.date);
          final isSelected = _selectedDate != null &&
              _selectedDate!.year == memo.date.year &&
              _selectedDate!.month == memo.date.month &&
              _selectedDate!.day == memo.date.day;

          return Padding(
            padding: const EdgeInsets.only(bottom: 24), // 날짜 간 간격 증가
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDate = null; // 선택 해제
                  } else {
                    _selectedDate = memo.date; // 선택
                  }
                });
              },
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                padding: isSelected ? const EdgeInsets.all(12) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 구분선과 버튼을 분리
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$dateStr ${'─' * 30}',
                            style: TextStyle(
                              fontSize: 15,
                              color: isSelected ? Colors.blue : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                    // 선택된 경우 수정/삭제 버튼 표시 (별도 줄)
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('수정'),
                              onPressed: () => _toggleEditMode(memo.date),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              label: const Text('삭제', style: TextStyle(color: Colors.red)),
                              onPressed: () => _deleteMemo(memo.date),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
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
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
