import 'package:cloud_firestore/cloud_firestore.dart';

class Memo {
  final String id;
  final String userId;
  final DateTime date; // 날짜만 (시간은 00:00:00)
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Memo({
    required this.id,
    required this.userId,
    required this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  // Firestore에 저장할 데이터
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Firestore에서 가져온 데이터를 Memo 객체로 변환
  factory Memo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Memo(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // 날짜 복사 (시간 제거)
  static DateTime dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}
