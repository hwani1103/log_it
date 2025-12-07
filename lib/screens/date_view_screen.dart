import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'work_log_detail_screen.dart';

class DateViewScreen extends StatefulWidget {
  const DateViewScreen({super.key});

  @override
  State<DateViewScreen> createState() => _DateViewScreenState();
}

class _DateViewScreenState extends State<DateViewScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final PageController _pageController = PageController();

  List<DateTime> _datesWithLogs = [];
  int _currentPageIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatesWithLogs();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      initialDate: _datesWithLogs.isNotEmpty
          ? _datesWithLogs[_currentPageIndex]
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final pickedDateOnly = DateTime(picked.year, picked.month, picked.day);
      final index = _datesWithLogs.indexWhere((date) =>
        date.year == pickedDateOnly.year &&
        date.month == pickedDateOnly.month &&
        date.day == pickedDateOnly.day
      );

      if (index != -1) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('해당 날짜에 작성된 일지가 없습니다')),
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

    if (_datesWithLogs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '작성된 일지가 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('yyyy년 MM월 dd일').format(_datesWithLogs[_currentPageIndex]),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('날짜 선택'),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            reverse: false, // 왼쪽 스와이프로 과거로 이동
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            itemCount: _datesWithLogs.length,
            itemBuilder: (context, index) {
              return DateLogsList(date: _datesWithLogs[index]);
            },
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
          return const Center(
            child: Text('해당 날짜에 작성된 일지가 없습니다'),
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
