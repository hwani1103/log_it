import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/equipment_alias_service.dart';
import 'work_log_detail_screen.dart';
import 'equipment_alias_settings_screen.dart';

// 설비 정보를 담는 클래스
class EquipmentInfo {
  final String name;
  final int logCount;
  final DateTime latestDate;

  EquipmentInfo({
    required this.name,
    required this.logCount,
    required this.latestDate,
  });
}

class EquipmentViewScreen extends StatefulWidget {
  const EquipmentViewScreen({super.key});

  @override
  State<EquipmentViewScreen> createState() => _EquipmentViewScreenState();
}

class _EquipmentViewScreenState extends State<EquipmentViewScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final EquipmentAliasService _aliasService = EquipmentAliasService();

  @override
  void initState() {
    super.initState();
    _aliasService.loadRules();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    return StreamBuilder<List<WorkLog>>(
      stream: _firestoreService.getAllWorkLogs(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('에러: ${snapshot.error}'));
        }

        final allLogs = snapshot.data ?? [];

        if (allLogs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '등록된 설비가 없습니다',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // 설비별로 그룹핑하여 정보 계산
        final Map<String, List<WorkLog>> equipmentLogsMap = {};
        for (var log in allLogs) {
          equipmentLogsMap.putIfAbsent(log.equipmentName, () => []).add(log);
        }

        // 설비 정보 리스트 생성
        final equipmentInfoList = equipmentLogsMap.entries.map((entry) {
          final logs = entry.value;
          logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return EquipmentInfo(
            name: entry.key,
            logCount: logs.length,
            latestDate: logs.first.createdAt,
          );
        }).toList();

        // 정렬: 1순위 날짜(최근순), 2순위 설비명(알파벳순)
        equipmentInfoList.sort((a, b) {
          final dateCompare = b.latestDate.compareTo(a.latestDate);
          if (dateCompare != 0) return dateCompare;
          return a.name.compareTo(b.name);
        });

        final allEquipmentNames = equipmentInfoList.map((e) => e.name).toList();

        return Column(
          children: [
            // 상단 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  // 설비 조회 버튼
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllEquipmentsScreen(
                              equipmentNames: allEquipmentNames,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('설비 조회'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 설정 아이콘
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EquipmentAliasSettingsScreen(
                            aliasService: _aliasService,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    color: Colors.blue,
                    tooltip: '설비명 변환 규칙',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: equipmentInfoList.length,
                itemBuilder: (context, index) {
                  final info = equipmentInfoList[index];
                  final dateStr = DateFormat('yy/MM/dd').format(info.latestDate);

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
                            builder: (context) => EquipmentHistoryScreen(
                              equipmentName: info.name,
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
                            Text(
                              info.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '설비 이력: ${info.logCount}개',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '가장 최근 이력: $dateStr',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
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

// 특정 설비의 날짜별 이력 화면
class EquipmentHistoryScreen extends StatelessWidget {
  final String equipmentName;

  const EquipmentHistoryScreen({
    super.key,
    required this.equipmentName,
  });

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();
    final userId = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(equipmentName),
      ),
      body: FutureBuilder<Map<DateTime, List<WorkLog>>>(
        future: firestoreService.getWorkLogsByEquipmentGroupedByDate(
          userId,
          equipmentName,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('에러: ${snapshot.error}'));
          }

          final groupedLogs = snapshot.data ?? {};

          if (groupedLogs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '해당 설비의 작업 이력이 없습니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // 날짜 순으로 정렬
          final sortedDates = groupedLogs.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          // 모든 일지를 날짜별로 평탄화
          final List<WorkLog> allLogs = [];
          for (final date in sortedDates) {
            allLogs.addAll(groupedLogs[date]!);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allLogs.length,
            itemBuilder: (context, index) {
              final log = allLogs[index];
              final dateStr = DateFormat('yyyy년 MM월 dd일').format(log.createdAt);

              // 내용 미리보기 (최대 50자)
              final preview = log.content.length > 50
                  ? '${log.content.substring(0, 50)}...'
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
                          showEquipmentFirst: true,
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
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preview.isNotEmpty ? preview : '내용 없음',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 특정 설비의 특정 날짜 일지 목록 화면
class EquipmentDateLogsScreen extends StatelessWidget {
  final String equipmentName;
  final DateTime date;
  final List<WorkLog> logs;

  const EquipmentDateLogsScreen({
    super.key,
    required this.equipmentName,
    required this.date,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              equipmentName,
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final timeStr = DateFormat('HH:mm').format(log.createdAt);

          // 내용 미리보기
          final preview = log.content.length > 100
              ? '${log.content.substring(0, 100)}...'
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
                      showEquipmentFirst: true,
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
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preview.isNotEmpty ? preview : '내용 없음',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      maxLines: 3,
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
      ),
    );
  }
}

// 모든 설비 그리드 화면
class AllEquipmentsScreen extends StatelessWidget {
  final List<String> equipmentNames;

  const AllEquipmentsScreen({
    super.key,
    required this.equipmentNames,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설비 조회'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
        ),
        itemCount: equipmentNames.length,
        itemBuilder: (context, index) {
          final equipmentName = equipmentNames[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EquipmentHistoryScreen(
                    equipmentName: equipmentName,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade300, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  equipmentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
