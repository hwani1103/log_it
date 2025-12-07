import 'package:flutter/material.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/work_log_card.dart';

class EquipmentViewScreen extends StatefulWidget {
  const EquipmentViewScreen({super.key});

  @override
  State<EquipmentViewScreen> createState() => _EquipmentViewScreenState();
}

class _EquipmentViewScreenState extends State<EquipmentViewScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedEquipment;
  List<String> _equipmentNames = [];

  @override
  void initState() {
    super.initState();
    _loadEquipmentNames();
  }

  Future<void> _loadEquipmentNames() async {
    final userId = _authService.currentUser?.uid ?? '';
    final names = await _firestoreService.getUniqueEquipmentNames(userId);
    setState(() {
      _equipmentNames = names;
      if (names.isNotEmpty && _selectedEquipment == null) {
        _selectedEquipment = names.first;
      }
    });
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
            children: [
              const Text(
                '설비 선택: ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _equipmentNames.isEmpty
                    ? const Text('등록된 설비가 없습니다')
                    : DropdownButton<String>(
                        value: _selectedEquipment,
                        isExpanded: true,
                        items: _equipmentNames.map((String name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedEquipment = newValue;
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedEquipment == null
              ? const Center(child: Text('설비를 선택하세요'))
              : StreamBuilder<List<WorkLog>>(
                  stream: _firestoreService.getWorkLogsByEquipment(
                    userId,
                    _selectedEquipment!,
                  ),
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
                        child: Text('해당 설비의 작업 이력이 없습니다'),
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
