import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/field.dart';
import '../models/review.dart';
import 'user_service.dart';

/// خدمة التقييمات — تقرأ وتكتب بمجموعة reviews،
/// وبوضع الاختبار (بدون Firebase) تشتغل على بيانات بالذاكرة.
class ReviewsService {
  ReviewsService._();

  static final ReviewsService instance = ReviewsService._();

  /// يزيد مع كل نشر/حذف — الشاشات تسمعه وتتحدث
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get _useMock => Firebase.apps.isEmpty;

  String get _uid => _useMock
      ? 'mock-user'
      : FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('reviews');

  /// تقييمات تجريبية لملعب النجوم — حتى القسم يبين حي بالاختبار
  late final List<Review> _mockReviews = [
    Review(
      id: 'f1_other-1',
      fieldId: 'f1',
      fieldName: 'ملعب النجوم',
      userId: 'other-1',
      userName: 'مصطفى',
      rating: 5,
      comment: 'أرضية ممتازة وإضاءة قوية، والحجز بالتطبيق وفّر علينا وجع الراس',
      createdAtMs: DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch,
    ),
    Review(
      id: 'f1_other-2',
      fieldId: 'f1',
      fieldName: 'ملعب النجوم',
      userId: 'other-2',
      userName: 'علي',
      rating: 4,
      comment: 'حلو بس المواقف تمتلئ بسرعة أيام الخميس',
      createdAtMs: DateTime.now()
          .subtract(const Duration(days: 6))
          .millisecondsSinceEpoch,
    ),
  ];

  /// تقييمات ملعب معيّن — الأحدث أولاً
  Future<List<Review>> fieldReviews(String fieldId) async {
    if (_useMock) {
      final list = _mockReviews.where((r) => r.fieldId == fieldId).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      return list;
    }

    final snapshot = await _col
        .where('fieldId', isEqualTo: fieldId)
        .get()
        .timeout(const Duration(seconds: 10));
    final reviews = [
      for (final doc in snapshot.docs) Review.fromMap(doc.id, doc.data()),
    ]..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return reviews;
  }

  /// تقييماتي بكل الملاعب — الأحدث أولاً
  Future<List<Review>> myReviews() async {
    if (_useMock) {
      final list = _mockReviews.where((r) => r.userId == _uid).toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      return list;
    }

    final snapshot = await _col
        .where('userId', isEqualTo: _uid)
        .get()
        .timeout(const Duration(seconds: 10));
    final reviews = [
      for (final doc in snapshot.docs) Review.fromMap(doc.id, doc.data()),
    ]..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return reviews;
  }

  /// نشر أو تعديل تقييمي لملعب (تقييم واحد لكل مستخدم بالملعب)
  Future<void> submitReview(
    Field field, {
    required int rating,
    String comment = '',
  }) async {
    final name = UserService.instance.name;
    final review = Review(
      id: '${field.id}_$_uid',
      fieldId: field.id,
      fieldName: field.name,
      userId: _uid,
      userName: name.isEmpty ? 'لاعب' : name,
      rating: rating,
      comment: comment.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    if (_useMock) {
      _mockReviews.removeWhere((r) => r.id == review.id);
      _mockReviews.add(review);
      revision.value++;
      return;
    }

    await _col
        .doc(review.id)
        .set(review.toMap())
        .timeout(const Duration(seconds: 15));
    revision.value++;
  }

  /// حذف تقييمي
  Future<void> deleteReview(Review review) async {
    if (_useMock) {
      _mockReviews.removeWhere((r) => r.id == review.id);
      revision.value++;
      return;
    }

    await _col
        .doc(review.id)
        .delete()
        .timeout(const Duration(seconds: 15));
    revision.value++;
  }

  /// تقييمي الحالي بملعب معيّن (إن وجد) من قائمة محمّلة
  Review? myReviewIn(List<Review> reviews) {
    for (final r in reviews) {
      if (r.userId == _uid) return r;
    }
    return null;
  }
}
