import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/player_request.dart';

/// خدمة "انضمامات" إعلانات ناقصنا لاعب — دليل حقيقي كل مرة لاعب يتطوع
/// يكمّل نقص فريق. هذا هو المصدر الوحيد لشارة "منقذ": بدونها ما بيه أي
/// طريقة نعرف بيها إذا لاعب أكمل فريق ناقص فعلاً (التطبيق أصلاً ما كان
/// يسجّل هذا الفعل — التواصل يصير برّا التطبيق بواتساب/اتصال).
///
/// معرّف المستند requestId_uid يمنع الانضمام المكرر لنفس الإعلان (يحسب
/// مرة وحدة بس مهما ضغط الزر أكثر من مرة).
class RequestResponsesService {
  RequestResponsesService._();

  static final RequestResponsesService instance = RequestResponsesService._();

  /// يزيد مع كل انضمام/انسحاب — البطاقات تسمعه وتحدّث حالتها
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get _useMock => Firebase.apps.isEmpty;

  String get _uid =>
      _useMock ? 'mock-user' : FirebaseAuth.instance.currentUser?.uid ?? '';

  /// انضمامات وضع الاختبار — معرّفات بصيغة requestId_uid
  final Set<String> _mockResponses = {};

  /// معرّفات الإعلانات اللي انضم إلها المستخدم الحالي (من آخر [loadMyResponses])
  final Set<String> _myResponses = {};

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('requestResponses');

  String _idFor(String requestId) => '${requestId}_$_uid';

  /// انضمام جاري؟ (بمعرّف الإعلان) — منع الضغط المكرر
  final Set<String> _joining = {};

  /// تسجيل انضمام حقيقي — "أني بيجي أكمل النقص". ما تنفع على إعلانك انت.
  Future<void> respond(PlayerRequest request) async {
    if (request.userId == _uid) return;
    if (!_joining.add(request.id)) return;
    try {
      final id = _idFor(request.id);
      if (_useMock) {
        _mockResponses.add(id);
        _myResponses.add(request.id);
        revision.value++;
        return;
      }

      await _col
          .doc(id)
          .set({
            'requestId': request.id,
            'requesterId': request.userId,
            'joinerId': _uid,
            'sport': request.sport.name,
            'date': request.date,
            'hour': request.hour,
            'place': request.place,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
      _myResponses.add(request.id);
      revision.value++;
    } finally {
      _joining.remove(request.id);
    }
  }

  /// التراجع عن انضمام (تصحيح ضغطة غلط)
  Future<void> withdraw(PlayerRequest request) async {
    if (!_joining.add(request.id)) return;
    try {
      final id = _idFor(request.id);
      if (_useMock) {
        _mockResponses.remove(id);
        _myResponses.remove(request.id);
        revision.value++;
        return;
      }

      await _col.doc(id).delete().timeout(const Duration(seconds: 15));
      _myResponses.remove(request.id);
      revision.value++;
    } finally {
      _joining.remove(request.id);
    }
  }

  /// هل انضممت لهذا الإعلان؟ (من آخر تحميل عبر [loadMyResponses])
  bool hasResponded(String requestId) => _myResponses.contains(requestId);

  /// يجيب انضماماتي ضمن دفعة إعلانات معروضة — استعلام وحد بدل واحد لكل بطاقة
  Future<void> loadMyResponses(List<String> requestIds) async {
    if (requestIds.isEmpty) return;
    if (_useMock) {
      _myResponses
        ..clear()
        ..addAll([
          for (final id in requestIds)
            if (_mockResponses.contains(_idFor(id))) id,
        ]);
      return;
    }

    try {
      // whereIn محدودة بـ ٣٠ عنصر — كافية (حجم الدفعة الوحدة ٢٠)
      final snapshot = await _col
          .where('joinerId', isEqualTo: _uid)
          .where('requestId', whereIn: requestIds.take(30).toList())
          .get()
          .timeout(const Duration(seconds: 10));
      _myResponses
        ..clear()
        ..addAll([
          for (final doc in snapshot.docs)
            (doc.data()['requestId'] as String?) ?? '',
        ]);
    } catch (_) {
      // بدون نت: الأزرار تبقى بحالتها الافتراضية (ما ننضم)
    }
  }

  /// عدد مرات إكمال نقص فريق — لشارة "منقذ" بملف اللاعب
  Future<int> gapsFilledCount(String uid) async {
    if (_useMock) {
      return _mockResponses.where((id) => id.endsWith('_$uid')).length;
    }
    try {
      final snap = await _col
          .where('joinerId', isEqualTo: uid)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// تصفير وضع الاختبار — للاختبارات فقط
  @visibleForTesting
  void debugReset() {
    _mockResponses.clear();
    _myResponses.clear();
    revision.value++;
  }
}
