import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/work_log.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'work_logs';

  Future<void> createWorkLog(WorkLog workLog) async {
    await _firestore.collection(_collection).add(workLog.toFirestore());
  }

  Future<void> updateWorkLog(String id, WorkLog workLog) async {
    await _firestore.collection(_collection).doc(id).update(workLog.toFirestore());
  }

  Future<void> deleteWorkLog(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<WorkLog>> getWorkLogsByDate(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList());
  }

  Stream<List<WorkLog>> getWorkLogsByEquipment(String userId, String equipmentName) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('equipmentName', isEqualTo: equipmentName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList());
  }

  Stream<List<WorkLog>> getAllWorkLogs(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => WorkLog.fromFirestore(doc)).toList());
  }

  Future<List<String>> getUniqueEquipmentNames(String userId) async {
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

    return equipmentNames.toList()..sort();
  }

  // 최근 일지 작성된 설비 순으로 정렬하여 각 설비의 최근 일지 가져오기
  Future<Map<String, WorkLog>> getEquipmentsWithLatestLog(String userId) async {
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

    return equipmentLatestLogs;
  }

  // 일지가 존재하는 날짜 목록 가져오기 (최신순)
  Future<List<DateTime>> getDatesWithLogs(String userId) async {
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

    return dates.toList();
  }

  // 특정 설비의 날짜별 일지 그룹핑
  Future<Map<DateTime, List<WorkLog>>> getWorkLogsByEquipmentGroupedByDate(
    String userId,
    String equipmentName,
  ) async {
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

    return groupedLogs;
  }
}
