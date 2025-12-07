import 'package:cloud_firestore/cloud_firestore.dart';

class WorkLog {
  final String id;
  final String userId;
  final String equipmentName;
  final String content;
  final DateTime createdAt;
  final List<String> mediaUrls;
  final List<String> mediaTypes;

  WorkLog({
    required this.id,
    required this.userId,
    required this.equipmentName,
    required this.content,
    required this.createdAt,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
  });

  factory WorkLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      equipmentName: data['equipmentName'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      mediaTypes: List<String>.from(data['mediaTypes'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'equipmentName': equipmentName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'mediaUrls': mediaUrls,
      'mediaTypes': mediaTypes,
    };
  }
}
