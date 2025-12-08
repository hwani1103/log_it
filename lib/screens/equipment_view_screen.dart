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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  info.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '설비 이력: ${info.logCount}개',
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
class EquipmentHistoryScreen extends StatefulWidget {
  final String equipmentName;

  const EquipmentHistoryScreen({
    super.key,
    required this.equipmentName,
  });

  @override
  State<EquipmentHistoryScreen> createState() => _EquipmentHistoryScreenState();
}

class _EquipmentHistoryScreenState extends State<EquipmentHistoryScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late Future<Map<DateTime, List<WorkLog>>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    final userId = _authService.currentUser?.uid ?? '';
    setState(() {
      _logsFuture = _firestoreService.getWorkLogsByEquipmentGroupedByDate(
        userId,
        widget.equipmentName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.equipmentName),
      ),
      body: FutureBuilder<Map<DateTime, List<WorkLog>>>(
        future: _logsFuture,
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkLogDetailScreen(
                          workLog: log,
                          showEquipmentFirst: true,
                        ),
                      ),
                    );
                    // 상세 화면에서 돌아오면 다시 로드
                    _loadLogs();
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

// 모든 설비 리스트 화면
class AllEquipmentsScreen extends StatelessWidget {
  final List<String> equipmentNames;

  const AllEquipmentsScreen({
    super.key,
    required this.equipmentNames,
  });

  // 설비명을 파싱하여 정렬 키 생성
  List<int> _parseEquipmentForSort(String name) {
    final pattern = RegExp(r'^([A-Z]+)-?(\d+)([A-Z0-9]*)$');
    final match = pattern.firstMatch(name);

    if (match != null) {
      final prefix = match.group(1)!;  // RE, AB 등
      final number = int.tryParse(match.group(2)!) ?? 0;  // 8501
      final suffix = match.group(3) ?? '';  // A1, B1 등

      // prefix를 숫자로 변환 (A=1, B=2, ...)
      int prefixValue = 0;
      for (int i = 0; i < prefix.length; i++) {
        prefixValue = prefixValue * 26 + (prefix.codeUnitAt(i) - 64);
      }

      // suffix를 숫자로 변환
      int suffixValue = 0;
      for (int i = 0; i < suffix.length; i++) {
        final char = suffix.codeUnitAt(i);
        if (char >= 65 && char <= 90) {  // A-Z
          suffixValue = suffixValue * 36 + (char - 64);
        } else if (char >= 48 && char <= 57) {  // 0-9
          suffixValue = suffixValue * 36 + (char - 48 + 27);
        }
      }

      return [prefixValue, number, suffixValue];
    }

    // 파싱 실패 시 문자열 그대로
    return [0, 0, 0];
  }

  @override
  Widget build(BuildContext context) {
    // 설비명 정렬
    final sortedNames = List<String>.from(equipmentNames);
    sortedNames.sort((a, b) {
      final aKeys = _parseEquipmentForSort(a);
      final bKeys = _parseEquipmentForSort(b);

      // prefix 비교
      if (aKeys[0] != bKeys[0]) return aKeys[0].compareTo(bKeys[0]);
      // number 비교
      if (aKeys[1] != bKeys[1]) return aKeys[1].compareTo(bKeys[1]);
      // suffix 비교
      return aKeys[2].compareTo(bKeys[2]);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('설비 조회'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedNames.length,
        itemBuilder: (context, index) {
          final equipmentName = sortedNames[index];
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
                ),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Text(
                  equipmentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
