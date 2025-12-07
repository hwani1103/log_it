import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/work_log_card.dart';

class DateViewScreen extends StatefulWidget {
  const DateViewScreen({super.key});

  @override
  State<DateViewScreen> createState() => _DateViewScreenState();
}

class _DateViewScreenState extends State<DateViewScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('yyyy년 MM월 dd일').format(_selectedDate),
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
          child: StreamBuilder<List<WorkLog>>(
            stream: _firestoreService.getWorkLogsByDate(userId, _selectedDate),
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
                  return WorkLogCard(workLog: workLogs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
