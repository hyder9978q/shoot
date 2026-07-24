import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/venue_suggestion.dart';
import '../utils/input_sanitizer.dart';
import 'app_mode.dart';
import 'auth_service.dart';

/// خدمة "اقترح ملعب" — لاعب يبلغ عن ملعب/منشأة ما موجودة بالتطبيق بعد.
/// إذا أكثر من لاعب اقترح نفس الملعب (تطابق تقريبي بالاسم + المنطقة)
/// نزيد عدّاد الطلبات بدل ما نخلق سجل مكرر، حتى صاحب التطبيق يعرف
/// أكثر ملعب مطلوب فيسجّله أول.
class VenueSuggestionsService {
  VenueSuggestionsService._();

  static final VenueSuggestionsService instance = VenueSuggestionsService._();

  /// يزيد مع كل اقتراح جديد/تكرار أو تغيير حالة — الشاشات تسمعه وتحدث نفسها
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get _useMock => AppMode.isMock;

  String get _uid =>
      _useMock ? 'mock-user' : FirebaseAuth.instance.currentUser?.uid ?? '';

  /// نسخة تجريبية بالذاكرة — تفضل حية طول عمر التطبيق بوضع التجربة
  final List<VenueSuggestion> _mockSuggestions = [];

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('venueSuggestions');

  /// تطبيع نص عربي حتى تطابق الاقتراحات المتشابهة (تشكيل، تطويل، همزات
  /// وياء/هاء متغيّرة، مسافات زايدة) بدون ما نطلب من اللاعب كتابة دقيقة
  static String _normalize(String input) {
    var s = input.trim().toLowerCase();
    // تشكيل وتطويل
    s = s.replaceAll(RegExp(r'[ً-ْـ]'), '');
    // توحيد أشكال الألف والياء والهاء
    s = s.replaceAll(RegExp('[إأآا]'), 'ا');
    s = s.replaceAll('ى', 'ي');
    s = s.replaceAll('ة', 'ه');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// معرّف المستند من اسم الملعب + منطقته — نفس الملعب (حتى لو كتبه
  /// لاعب ثاني بصيغة مختلفة شوية) ينتهي بنفس المعرّف
  static String _docIdFor(String name, String area) {
    var key = '${_normalize(name)}_${_normalize(area)}'.replaceAll('/', '-');
    if (key.length > 300) key = key.substring(0, 300);
    return key.isEmpty ? 'suggestion' : key;
  }

  /// تحقق وتنظيف رقم تواصل الملعب — اختياري، لو انكتب لازم يكون رقم
  /// عراقي صحيح، ويرجع بصيغة دولية جاهزة للحفظ
  static String _cleanPhone(String phone) {
    final t = phone.trim();
    if (t.isEmpty) return '';
    if (!AuthService.isValidIraqiPhone(t)) {
      throw ArgumentError('رقم الملعب لازم يكون رقم عراقي صحيح (07XXXXXXXXX)');
    }
    return AuthService.toE164(t);
  }

  static String _cleanMapsUrl(String url) {
    final t = url.trim();
    if (t.isEmpty) return '';
    if (t.length > 500 || !t.startsWith('https://')) {
      throw ArgumentError('رابط الخرائط لازم يبدي بـ https://');
    }
    return t;
  }

  /// إرسال جاري؟ — ما نرسل اقتراحين بضغطة مكررة
  bool _posting = false;

  /// اقتراح ملعب جديد — إذا نفس الملعب (بنفس الاسم والمنطقة تقريباً)
  /// مقترح من قبل، نزيد عدّاد الطلبات بدل ما نخلق سجل مكرر. يرجع true
  /// لو هذا أول اقتراح لهذا الملعب، و false لو زاد عدّاد اقتراح موجود.
  Future<bool> suggestVenue({
    required String name,
    required String area,
    String mapsUrl = '',
    String phone = '',
    String note = '',
  }) async {
    if (_posting) return false;
    _posting = true;
    try {
      return await _suggestVenue(
        name: name,
        area: area,
        mapsUrl: mapsUrl,
        phone: phone,
        note: note,
      );
    } finally {
      _posting = false;
    }
  }

  Future<bool> _suggestVenue({
    required String name,
    required String area,
    required String mapsUrl,
    required String phone,
    required String note,
  }) async {
    final cleanName = InputSanitizer.clean(name, maxLength: 50);
    final cleanArea = InputSanitizer.clean(area, maxLength: 50);
    if (cleanName.isEmpty) throw ArgumentError('اكتب اسم الملعب');
    if (cleanArea.isEmpty) throw ArgumentError('اكتب المدينة أو المنطقة');
    final cleanMapsUrl = _cleanMapsUrl(mapsUrl);
    final cleanPhone = _cleanPhone(phone);
    final cleanNote = InputSanitizer.clean(note, maxLength: 200);
    final uid = _uid;
    final docId = _docIdFor(cleanName, cleanArea);

    if (_useMock) {
      final existingIndex = _mockSuggestions.indexWhere((s) => s.id == docId);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (existingIndex == -1) {
        _mockSuggestions.add(
          VenueSuggestion(
            id: docId,
            name: cleanName,
            area: cleanArea,
            userId: uid,
            requesterIds: [uid],
            requestCount: 1,
            status: VenueSuggestionStatus.pending,
            mapsUrl: cleanMapsUrl,
            phone: cleanPhone,
            note: cleanNote,
            createdAtMs: now,
            updatedAtMs: now,
          ),
        );
        revision.value++;
        return true;
      }
      final existing = _mockSuggestions[existingIndex];
      if (!existing.requesterIds.contains(uid)) {
        _mockSuggestions[existingIndex] = VenueSuggestion(
          id: existing.id,
          name: existing.name,
          area: existing.area,
          userId: existing.userId,
          requesterIds: [...existing.requesterIds, uid],
          requestCount: existing.requestCount + 1,
          status: existing.status,
          mapsUrl: existing.mapsUrl,
          phone: existing.phone,
          note: existing.note,
          createdAtMs: existing.createdAtMs,
          updatedAtMs: now,
        );
        revision.value++;
      }
      return false;
    }

    final ref = _col.doc(docId);
    final isNew = await FirebaseFirestore.instance
        .runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) {
            tx.set(ref, {
              'name': cleanName,
              'area': cleanArea,
              'userId': uid,
              'requesterIds': [uid],
              'requestCount': 1,
              'status': VenueSuggestionStatus.pending.name,
              'mapsUrl': cleanMapsUrl,
              'phone': cleanPhone,
              'note': cleanNote,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return true;
          }
          final requesterIds = [
            for (final u in (snap.data()?['requesterIds'] as List?) ?? const [])
              if (u is String) u,
          ];
          if (!requesterIds.contains(uid)) {
            tx.update(ref, {
              'requestCount': FieldValue.increment(1),
              'requesterIds': FieldValue.arrayUnion([uid]),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          return false;
        })
        .timeout(const Duration(seconds: 15));
    revision.value++;
    return isNew;
  }

  /// اقتراحاتي — كل ملعب طلبته انا (سواء كنت أول من اقترحه أو زدت
  /// عدّاد اقتراح موجود)، الأحدث أولاً
  Future<List<VenueSuggestion>> mySuggestions() async {
    final uid = _uid;
    if (uid.isEmpty) return const [];

    if (_useMock) {
      final mine = _mockSuggestions
          .where((s) => s.requesterIds.contains(uid))
          .toList()
        ..sort((a, b) => (b.updatedAtMs ?? 0).compareTo(a.updatedAtMs ?? 0));
      return mine;
    }

    final snapshot = await _col
        .where('requesterIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .get()
        .timeout(const Duration(seconds: 10));
    return [
      for (final doc in snapshot.docs)
        VenueSuggestion.fromMap(doc.id, _withMsTimestamps(doc.data())),
    ];
  }

  /// كل الاقتراحات مرتّبة بعدد الطلبات (الأكثر أولاً) — للوحة الإدارة فقط
  Future<List<VenueSuggestion>> allSuggestions() async {
    if (_useMock) {
      final all = [..._mockSuggestions]
        ..sort((a, b) => b.requestCount.compareTo(a.requestCount));
      return all;
    }

    final snapshot = await _col
        .orderBy('requestCount', descending: true)
        .get()
        .timeout(const Duration(seconds: 10));
    return [
      for (final doc in snapshot.docs)
        VenueSuggestion.fromMap(doc.id, _withMsTimestamps(doc.data())),
    ];
  }

  /// تغيير حالة اقتراح — للمسؤول فقط (تتحقق منه الواجهة وقواعد Firestore)
  Future<void> updateStatus(
    VenueSuggestion suggestion,
    VenueSuggestionStatus status,
  ) async {
    if (_useMock) {
      final i = _mockSuggestions.indexWhere((s) => s.id == suggestion.id);
      if (i == -1) return;
      final existing = _mockSuggestions[i];
      _mockSuggestions[i] = VenueSuggestion(
        id: existing.id,
        name: existing.name,
        area: existing.area,
        userId: existing.userId,
        requesterIds: existing.requesterIds,
        requestCount: existing.requestCount,
        status: status,
        mapsUrl: existing.mapsUrl,
        phone: existing.phone,
        note: existing.note,
        createdAtMs: existing.createdAtMs,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      revision.value++;
      return;
    }

    await _col
        .doc(suggestion.id)
        .update({
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 15));
    revision.value++;
  }

  /// يحوّل createdAt/updatedAt (Timestamp) إلى ميلي ثانية حتى يقرأها الموديل
  Map<String, dynamic> _withMsTimestamps(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    return {
      ...data,
      if (createdAt is Timestamp) 'createdAtMs': createdAt.millisecondsSinceEpoch,
      if (updatedAt is Timestamp) 'updatedAtMs': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// تصفير الحالة التجريبية بين الاختبارات (وضع التجربة فقط — الحقيقي
  /// يرجع Firestore)
  @visibleForTesting
  void debugReset() => _mockSuggestions.clear();

  /// معرّف المستند المبني من الاسم والمنطقة — يفضح منطق التطابق
  /// التقريبي للاختبارات بدون الحاجة نلمس الحالة الداخلية
  @visibleForTesting
  static String debugDocIdFor(String name, String area) =>
      _docIdFor(name, area);
}
