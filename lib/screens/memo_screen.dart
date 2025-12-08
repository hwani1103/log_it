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

  List<Memo> _memos = [];
  bool _isLoading = true;
  String? _editingMemoId; // 현재 편집 중인 메모 ID (날짜 기준)
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMemos() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.currentUser?.uid ?? '';
      final memos = await _memoService.getAllMemos(userId);

      setState(() {
        _memos = memos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메모 로드 실패: $e')),
        );
      }
    }
  }

  String _getDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  TextEditingController _getController(String dateKey, String initialContent) {
    if (!_controllers.containsKey(dateKey)) {
      _controllers[dateKey] = TextEditingController(text: initialContent);
    }
    return _controllers[dateKey]!;
  }

  void _startEditing(String dateKey) {
    setState(() {
      _editingMemoId = dateKey;
    });
  }

  Future<void> _saveMemo(DateTime date, String content) async {
    try {
      final userId = _authService.currentUser?.uid ?? '';
      await _memoService.saveMemo(userId, date, content);

      setState(() {
        _editingMemoId = null;
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

  void _cancelEditing() {
    setState(() {
      _editingMemoId = null;
    });
  }

  void _createTodayMemo() {
    final today = Memo.dateOnly(DateTime.now());
    final dateKey = _getDateKey(today);

    _getController(dateKey, '');
    _startEditing(dateKey);
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';
    final today = Memo.dateOnly(DateTime.now());
    final todayMemo = _memos.where((m) => Memo.dateOnly(m.date).isAtSameMomentAs(today)).firstOrNull;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 오늘 메모 섹션 (항상 표시)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateHeader(today, todayMemo),
                      const SizedBox(height: 12),
                      _buildMemoContent(today, todayMemo),
                    ],
                  ),
                ),

                // 이전 메모들 (스크롤)
                Expanded(
                  child: _memos.where((m) => Memo.dateOnly(m.date).isBefore(today)).isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              '이전 메모가 없습니다',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _memos.where((m) => Memo.dateOnly(m.date).isBefore(today)).length,
                          itemBuilder: (context, index) {
                            final pastMemos = _memos.where((m) => Memo.dateOnly(m.date).isBefore(today)).toList();
                            final memo = pastMemos[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDateHeader(memo.date, memo),
                                  const SizedBox(height: 12),
                                  _buildMemoContent(memo.date, memo),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateHeader(DateTime date, Memo? memo) {
    final dateKey = _getDateKey(date);
    final isEditing = _editingMemoId == dateKey;
    final dateStr = DateFormat('M월 d일').format(date);

    return Row(
      children: [
        Text(
          dateStr,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
        const SizedBox(width: 12),
        if (isEditing)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: _cancelEditing,
                tooltip: '취소',
                color: Colors.grey,
              ),
              IconButton(
                icon: const Icon(Icons.save, size: 20),
                onPressed: () {
                  final controller = _getController(dateKey, memo?.content ?? '');
                  _saveMemo(date, controller.text);
                },
                tooltip: '저장',
                color: Colors.blue,
              ),
            ],
          )
        else
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              final controller = _getController(dateKey, memo?.content ?? '');
              _startEditing(dateKey);
            },
            tooltip: '편집',
            color: Colors.blue,
          ),
      ],
    );
  }

  Widget _buildMemoContent(DateTime date, Memo? memo) {
    final dateKey = _getDateKey(date);
    final isEditing = _editingMemoId == dateKey;
    final controller = _getController(dateKey, memo?.content ?? '');

    if (isEditing) {
      return TextField(
        controller: controller,
        maxLines: null,
        minLines: 3,
        decoration: InputDecoration(
          hintText: '자유롭게 메모를 작성하세요...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        style: const TextStyle(fontSize: 15, height: 1.5),
        autofocus: true,
      );
    } else {
      if (memo == null || memo.content.isEmpty) {
        return GestureDetector(
          onTap: () => _startEditing(dateKey),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              '메모를 작성하려면 편집 버튼을 눌러주세요',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        );
      } else {
        return GestureDetector(
          onTap: () => _startEditing(dateKey),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              memo.content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        );
      }
    }
  }
}
