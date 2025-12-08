import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'work_log_detail_screen.dart';
import 'create_log_screen.dart';

class DateViewScreen extends StatefulWidget {
  const DateViewScreen({super.key});

  @override
  State<DateViewScreen> createState() => _DateViewScreenState();
}

class _DateViewScreenState extends State<DateViewScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  List<DateTime> _datesWithLogs = [];
  DateTime _currentDate = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 오늘 날짜로 초기화 (시간은 00:00:00)
    _currentDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _loadDatesWithLogs();
  }

  Future<void> _loadDatesWithLogs() async {
    final userId = _authService.currentUser?.uid ?? '';
    final dates = await _firestoreService.getDatesWithLogs(userId);

    setState(() {
      _datesWithLogs = dates;
      _isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // 미래 날짜 선택 불가
    );

    if (picked != null) {
      setState(() {
        _currentDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _goToPreviousDateWithLog() {
    // 현재 날짜보다 이전 날짜 중 일지가 있는 날짜 찾기
    final previousDates = _datesWithLogs.where((date) => date.isBefore(_currentDate)).toList();
    if (previousDates.isNotEmpty) {
      setState(() {
        _currentDate = previousDates.first; // 가장 최근 날짜
      });
    }
  }

  void _goToNextDateWithLog() {
    // 현재 날짜보다 이후 날짜 중 일지가 있는 날짜 찾기
    final nextDates = _datesWithLogs.where((date) => date.isAfter(_currentDate)).toList();
    if (nextDates.isNotEmpty) {
      setState(() {
        _currentDate = nextDates.last; // 가장 오래된 날짜 (reversed list이므로)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasPreviousLog = _datesWithLogs.any((date) => date.isBefore(_currentDate));
    final hasNextLog = _datesWithLogs.any((date) => date.isAfter(_currentDate));
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isFutureDate = _currentDate.isAfter(today);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              // 일지 작성 버튼 (왼쪽)
              IconButton(
                onPressed: isFutureDate ? null : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateLogScreen(selectedDate: _currentDate),
                    ),
                  );
                  // 일지 작성 후 목록 새로고침
                  _loadDatesWithLogs();
                },
                icon: const Icon(Icons.edit, size: 24),
                color: isFutureDate ? Colors.grey : Colors.blue,
                tooltip: '일지 작성',
              ),
              // 중앙: < 버튼, 날짜, > 버튼
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // < 버튼 (이전 일지)
                    IconButton(
                      onPressed: hasPreviousLog ? _goToPreviousDateWithLog : null,
                      icon: const Icon(Icons.chevron_left, size: 28),
                      color: hasPreviousLog ? Colors.black87 : Colors.grey.shade300,
                    ),
                    // 날짜 표시
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        DateFormat('yyyy년 MM월 dd일').format(_currentDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // > 버튼 (다음 일지)
                    IconButton(
                      onPressed: hasNextLog ? _goToNextDateWithLog : null,
                      icon: const Icon(Icons.chevron_right, size: 28),
                      color: hasNextLog ? Colors.black87 : Colors.grey.shade300,
                    ),
                  ],
                ),
              ),
              // 달력 아이콘 (우측)
              IconButton(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today, size: 20),
                color: Colors.blue,
                tooltip: '날짜 선택',
              ),
            ],
          ),
        ),
        Expanded(
          child: DateLogsList(
            date: _currentDate,
            key: ValueKey(_currentDate.toString()),
          ),
        ),
      ],
    );
  }
}

class DateLogsList extends StatefulWidget {
  final DateTime date;

  const DateLogsList({
    super.key,
    required this.date,
  });

  @override
  State<DateLogsList> createState() => _DateLogsListState();
}

class _DateLogsListState extends State<DateLogsList> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedLogs(List<WorkLog> workLogs) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일지 삭제'),
        content: Text('선택한 ${_selectedIds.length}개의 일지를 삭제하시겠습니까?\n첨부파일도 함께 삭제됩니다.'),
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
        final firestoreService = FirestoreService();
        final storageService = StorageService();

        // 선택된 일지들 찾기
        final logsToDelete = workLogs.where((log) => _selectedIds.contains(log.id)).toList();

        for (final log in logsToDelete) {
          // 미디어 파일 삭제
          for (final mediaUrl in log.mediaUrls) {
            try {
              await storageService.deleteMedia(mediaUrl);
            } catch (e) {
              print('미디어 삭제 실패: $e');
            }
          }

          // Firestore에서 일지 삭제
          await firestoreService.deleteWorkLog(log.id);
        }

        if (mounted) {
          setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${logsToDelete.length}개의 일지가 삭제되었습니다')),
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

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();
    final userId = authService.currentUser?.uid ?? '';

    return StreamBuilder<List<WorkLog>>(
      stream: firestoreService.getWorkLogsByDate(userId, widget.date),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('에러: ${snapshot.error}'));
        }

        final workLogs = snapshot.data ?? [];

        if (workLogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  '${DateFormat('MM월 dd일').format(widget.date)}에\n작성된 일지가 없습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 다중 선택 모드 헤더
            if (_isSelectionMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.blue.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedIds.length}개 선택됨',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _toggleSelectionMode,
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () => _deleteSelectedLogs(workLogs),
                          icon: const Icon(Icons.delete, size: 18),
                          label: const Text('삭제'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: workLogs.length,
                itemBuilder: (context, index) {
                  final log = workLogs[index];
                  final isSelected = _selectedIds.contains(log.id);

                  // 내용 미리보기
                  final preview = log.content.length > 80
                      ? '${log.content.substring(0, 80)}...'
                      : log.content;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    color: isSelected ? Colors.blue.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(log.id);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkLogDetailScreen(
                                workLog: log,
                                showEquipmentFirst: false,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedIds.add(log.id);
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // 체크박스 (다중 선택 모드일 때만)
                            if (_isSelectionMode) ...[
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) => _toggleSelection(log.id),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        log.equipmentName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('HH:mm').format(log.createdAt),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    preview.isNotEmpty ? preview : '내용 없음',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (log.mediaUrls.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.attach_file,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '첨부 ${log.mediaUrls.length}개',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
