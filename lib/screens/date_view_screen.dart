import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 일지 작성 버튼
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
              // 현재 날짜 표시
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('yyyy년 MM월 dd일').format(_currentDate),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // 날짜 선택 버튼
              ElevatedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('날짜 선택'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              // 왼쪽으로 스와이프 (이전 일지로)
              if (details.primaryVelocity! < 0 && hasPreviousLog) {
                _goToPreviousDateWithLog();
              }
              // 오른쪽으로 스와이프 (다음 일지로)
              else if (details.primaryVelocity! > 0 && hasNextLog) {
                _goToNextDateWithLog();
              }
            },
            child: DateLogsList(
              date: _currentDate,
              key: ValueKey(_currentDate.toString()),
            ),
          ),
        ),
      ],
    );
  }
}

class DateLogsList extends StatelessWidget {
  final DateTime date;

  const DateLogsList({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();
    final userId = authService.currentUser?.uid ?? '';

    return StreamBuilder<List<WorkLog>>(
      stream: firestoreService.getWorkLogsByDate(userId, date),
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
                  '${DateFormat('MM월 dd일').format(date)}에\n작성된 일지가 없습니다',
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workLogs.length,
          itemBuilder: (context, index) {
            final log = workLogs[index];

            // 내용 미리보기
            final preview = log.content.length > 80
                ? '${log.content.substring(0, 80)}...'
                : log.content;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkLogDetailScreen(
                        workLog: log,
                        showEquipmentFirst: false,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
              ),
            );
          },
        );
      },
    );
  }
}
