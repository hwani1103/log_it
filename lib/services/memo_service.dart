import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memo.dart';

class MemoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'memos';

  // 특정 날짜의 메모 가져오기
  Future<Memo?> getMemoByDate(String userId, DateTime date) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 메모 조회');
    print('날짜: ${date.year}-${date.month}-${date.day}');
    print('===========================================');

    final dateOnly = Memo.dateOnly(date);
    final nextDay = dateOnly.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateOnly))
        .where('date', isLessThan: Timestamp.fromDate(nextDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      print('✅ [Firestore] 메모 없음');
      return null;
    }

    print('✅ [Firestore] 메모 조회 완료');
    return Memo.fromFirestore(snapshot.docs.first);
  }

  // 모든 메모 가져오기 (클라이언트에서 날짜 내림차순 정렬)
  Future<List<Memo>> getAllMemos(String userId) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 전체 메모 조회');
    print('===========================================');

    final snapshot = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .get();

    print('✅ [Firestore] 메모 ${snapshot.docs.length}개 조회 완료');

    final memos = snapshot.docs.map((doc) => Memo.fromFirestore(doc)).toList();

    // 클라이언트에서 날짜 오름차순 정렬 (오래된 날짜가 위에)
    memos.sort((a, b) => a.date.compareTo(b.date));

    return memos;
  }

  // 메모 저장 (생성 또는 업데이트)
  Future<void> saveMemo(String userId, DateTime date, String content) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 메모 저장');
    print('날짜: ${date.year}-${date.month}-${date.day}');
    print('===========================================');

    final dateOnly = Memo.dateOnly(date);
    final nextDay = dateOnly.add(const Duration(days: 1));

    // 기존 메모 찾기
    final existing = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateOnly))
        .where('date', isLessThan: Timestamp.fromDate(nextDay))
        .limit(1)
        .get();

    final now = DateTime.now();

    if (existing.docs.isEmpty) {
      // 새 메모 생성
      final memo = Memo(
        id: '',
        userId: userId,
        date: dateOnly,
        content: content,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection(_collection).add(memo.toFirestore());
      print('✅ [Firestore] 새 메모 생성 완료');
    } else {
      // 기존 메모 업데이트
      await _firestore.collection(_collection).doc(existing.docs.first.id).update({
        'content': content,
        'updatedAt': Timestamp.fromDate(now),
      });
      print('✅ [Firestore] 메모 업데이트 완료');
    }
  }

  // 메모 삭제
  Future<void> deleteMemo(String memoId) async {
    print('=============== 네트워크 요청!! ===============');
    print('📡 [Firestore] 메모 삭제 (ID: $memoId)');
    print('===========================================');

    await _firestore.collection(_collection).doc(memoId).delete();

    print('✅ [Firestore] 메모 삭제 완료');
  }
}
