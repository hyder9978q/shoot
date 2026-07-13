/// تقييم مستخدم لملعب — مستند بمجموعة reviews
///
/// معرّف المستند: fieldId_userId — يعني لكل مستخدم تقييم واحد
/// بالملعب الواحد (يكدر يعدّله بأي وقت).
class Review {
  const Review({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAtMs,
  });

  factory Review.fromMap(String id, Map<String, dynamic> data) {
    return Review(
      id: id,
      fieldId: (data['fieldId'] as String?) ?? '',
      fieldName: (data['fieldName'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      rating: ((data['rating'] as num?)?.toInt() ?? 5).clamp(1, 5),
      comment: (data['comment'] as String?) ?? '',
      createdAtMs: (data['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String fieldId;
  final String fieldName;
  final String userId;

  /// اسم صاحب التقييم وقت النشر (حتى ما نحتاج نقرأ ملفه)
  final String userName;

  /// النجوم 1–5
  final int rating;
  final String comment;

  /// وقت النشر بالمللي ثانية — للترتيب بدون فهارس
  final int createdAtMs;

  Map<String, dynamic> toMap() => {
        'fieldId': fieldId,
        'fieldName': fieldName,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'createdAtMs': createdAtMs,
      };
}
