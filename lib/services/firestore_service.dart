import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/work_log.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'work_logs';

  Future<WorkLog> createWorkLog(WorkLog workLog) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 일지 생성');
    print('설비명: ${workLog.equipmentName}');
    print('첨부파일: ${workLog.mediaUrls.length}개');
    print('===========================================');

    final docRef = await _firestore.collection(_collection).add(workLog.toFirestore());

    print('✅ [Firestore] 일지 생성 완료 (ID: ${docRef.id})');

    return WorkLog(
      id: docRef.id,
      userId: workLog.userId,
      equipmentName: workLog.equipmentName,
      content: workLog.content,
      createdAt: workLog.createdAt,
      mediaUrls: workLog.mediaUrls,
      mediaTypes: workLog.mediaTypes,
    );
  }

  Future<void> updateWorkLog(String id, WorkLog workLog) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 일지 수정');
    print('ID: $id');
    print('설비명: ${workLog.equipmentName}');
    print('===========================================');

    await _firestore.collection(_collection).doc(id).update(workLog.toFirestore());

    print('✅ [Firestore] 일지 수정 완료');
  }

  Future<void> deleteWorkLog(String id) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 일지 삭제');
    print('ID: $id');
    print('===========================================');

    await _firestore.collection(_collection).doc(id).delete();

    print('✅ [Firestore] 일지 삭제 완료');
  }

  Stream<List<WorkLog>> getWorkLogsByDate(String userId, DateTime date) {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 날짜별 일지 조회 (Stream)');
    print('날짜: ${date.year}-${date.month}-${date.day}');
    print('===========================================');

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('✅ [Firestore] 날짜별 일지 ${snapshot.docs.length}개 수신');
          return snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList();
        });
  }

  Stream<List<WorkLog>> getWorkLogsByEquipment(String userId, String equipmentName) {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 설비별 일지 조회 (Stream)');
    print('설비명: $equipmentName');
    print('===========================================');

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('equipmentName', isEqualTo: equipmentName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('✅ [Firestore] 설비별 일지 ${snapshot.docs.length}개 수신');
          return snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList();
        });
  }

  Stream<List<WorkLog>> getAllWorkLogs(String userId) {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 전체 일지 조회 (Stream)');
    print('===========================================');

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('✅ [Firestore] 전체 일지 ${snapshot.docs.length}개 수신');
          return snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList();
        });
  }

  Future<List<String>> getUniqueEquipmentNames(String userId) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 설비명 목록 조회');
    print('===========================================');

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .get();

    final equipmentNames = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['equipmentName'] != null) {
        equipmentNames.add(data['equipmentName'] as String);
      }
    }

    print('✅ [Firestore] 설비명 ${equipmentNames.length}개 조회 완료');
    return equipmentNames.toList()..sort();
  }

  // 최근 일지 작성된 설비 순으로 정렬하여 각 설비의 최근 일지 가져오기
  Future<Map<String, WorkLog>> getEquipmentsWithLatestLog(String userId) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 설비별 최근 일지 조회');
    print('===========================================');

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final Map<String, WorkLog> equipmentLatestLogs = {};

    for (var doc in snapshot.docs) {
      final workLog = WorkLog.fromFirestore(doc);
      if (!equipmentLatestLogs.containsKey(workLog.equipmentName)) {
        equipmentLatestLogs[workLog.equipmentName] = workLog;
      }
    }

    print('✅ [Firestore] 설비 ${equipmentLatestLogs.length}개의 최근 일지 조회 완료');
    return equipmentLatestLogs;
  }

  // 일지가 존재하는 날짜 목록 가져오기 (최신순)
  Future<List<DateTime>> getDatesWithLogs(String userId) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 일지 존재하는 날짜 목록 조회');
    print('===========================================');

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    final Set<DateTime> dates = {};

    for (var doc in snapshot.docs) {
      final workLog = WorkLog.fromFirestore(doc);
      final dateOnly = DateTime(
        workLog.createdAt.year,
        workLog.createdAt.month,
        workLog.createdAt.day,
      );
      dates.add(dateOnly);
    }

    print('✅ [Firestore] 날짜 ${dates.length}개 조회 완료');
    return dates.toList();
  }

  // 특정 설비의 날짜별 일지 그룹핑
  Future<Map<DateTime, List<WorkLog>>> getWorkLogsByEquipmentGroupedByDate(
    String userId,
    String equipmentName,
  ) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 설비별 날짜별 일지 그룹핑 조회');
    print('설비명: $equipmentName');
    print('===========================================');

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('equipmentName', isEqualTo: equipmentName)
        .orderBy('createdAt', descending: true)
        .get();

    final Map<DateTime, List<WorkLog>> groupedLogs = {};

    for (var doc in snapshot.docs) {
      final workLog = WorkLog.fromFirestore(doc);
      final dateOnly = DateTime(
        workLog.createdAt.year,
        workLog.createdAt.month,
        workLog.createdAt.day,
      );

      if (!groupedLogs.containsKey(dateOnly)) {
        groupedLogs[dateOnly] = [];
      }
      groupedLogs[dateOnly]!.add(workLog);
    }

    print('✅ [Firestore] ${groupedLogs.length}개 날짜의 일지 그룹핑 완료');
    return groupedLogs;
  }
}
