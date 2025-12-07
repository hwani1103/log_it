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
}
