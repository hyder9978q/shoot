import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/ad.dart';
import '../models/field.dart';
import '../utils/date_labels.dart';
import '../utils/image_validation.dart';
import '../utils/input_sanitizer.dart';
import 'app_mode.dart';
import 'supabase_storage_service.dart';

export '../utils/image_validation.dart' show InvalidImageException;

/// خدمة إعلانات صاحب المنشأة — تقرأ وتكتب من Firestore، وبوضع التجربة
/// (بدون Firebase) تشتغل على قائمة بالذاكرة.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  /// يزيد مع كل نشر/تعديل/حذف — الشاشات تسمعه وتحدّث نفسها
  final ValueNotifier<int> revision = ValueNotifier(0);

  /// إعلانات وضع التجربة (بدون Firebase)
  final List<Ad> _mockAds = [];

  bool get _useMock => AppMode.isMock;

  String get _uid =>
      _useMock ? 'mock-user' : FirebaseAuth.instance.currentUser?.uid ?? '';

  static String _today() => DateLabels.dateFor(0);

  static const int titleMaxLength = 60;
  static const int bodyMaxLength = 300;

  /// فحص الملكية: صاحب المنشأة فقط ينشر/يعدّل إعلانات منشأته هو
  void _assertOwner(Field field) {
    final uid = _uid;
    if (uid.isEmpty || field.ownerId != uid) {
      throw StateError('غير مخوّل: هذي المنشأة مو تابعة لحسابك');
    }
  }

  /// فحص ملكية إعلان موجود مباشرة (بدون الحاجة لكائن Field كامل)
  void _assertAdOwner(Ad ad) {
    final uid = _uid;
    if (uid.isEmpty || ad.ownerId != uid) {
      throw StateError('غير مخوّل: هذا الإعلان مو تابع لحسابك');
    }
  }

  String _cleanTitle(String title) {
    final t = InputSanitizer.clean(title, maxLength: titleMaxLength);
    if (t.isEmpty) throw ArgumentError('عنوان الإعلان مطلوب');
    return t;
  }

  String _cleanBody(String body) {
    final t = InputSanitizer.clean(body, maxLength: bodyMaxLength);
    if (t.isEmpty) throw ArgumentError('نص الإعلان مطلوب');
    return t;
  }

  String _validateExpiry(String expiresAt) {
    final t = expiresAt.trim();
    if (t.compareTo(_today()) < 0) {
      throw ArgumentError('تاريخ الانتهاء لازم يكون اليوم أو بعده');
    }
    return t;
  }

  /// نشر إعلان جديد لمنشأة يملكها المستخدم الحالي
  Future<Ad> createAd(
    Field field, {
    required String title,
    required String body,
    required AdType type,
    required String expiresAt,
    String imageUrl = '',
  }) async {
    _assertOwner(field);
    final cleanTitle = _cleanTitle(title);
    final cleanBody = _cleanBody(body);
    final cleanExpiry = _validateExpiry(expiresAt);

    final ad = Ad(
      id: _useMock
          ? 'ad-${DateTime.now().microsecondsSinceEpoch}'
          : FirebaseFirestore.instance.collection('ads').doc().id,
      fieldId: field.id,
      ownerId: field.ownerId,
      fieldName: field.name,
      title: cleanTitle,
      body: cleanBody,
      type: type,
      expiresAt: cleanExpiry,
      imageUrl: imageUrl,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    if (_useMock) {
      _mockAds.add(ad);
      revision.value++;
      return ad;
    }

    await FirebaseFirestore.instance
        .collection('ads')
        .doc(ad.id)
        .set(ad.toMap())
        .timeout(const Duration(seconds: 15));
    revision.value++;
    return ad;
  }

  /// تعديل إعلان موجود — العنوان والنص والنوع وتاريخ الانتهاء والصورة
  Future<Ad> updateAd(
    Ad ad, {
    required String title,
    required String body,
    required AdType type,
    required String expiresAt,
    required String imageUrl,
  }) async {
    _assertAdOwner(ad);
    final cleanTitle = _cleanTitle(title);
    final cleanBody = _cleanBody(body);
    final cleanExpiry = _validateExpiry(expiresAt);

    final updated = ad.copyWith(
      title: cleanTitle,
      body: cleanBody,
      type: type,
      expiresAt: cleanExpiry,
      imageUrl: imageUrl,
    );

    if (_useMock) {
      final i = _mockAds.indexWhere((a) => a.id == ad.id);
      if (i != -1) _mockAds[i] = updated;
      revision.value++;
      return updated;
    }

    await FirebaseFirestore.instance
        .collection('ads')
        .doc(ad.id)
        .set(updated.toMap(), SetOptions(merge: true))
        .timeout(const Duration(seconds: 15));
    revision.value++;
    return updated;
  }

  /// إيقاف/إعادة تفعيل إعلان — بدون حذفه (يقدر يرجّعه لاحقاً)
  Future<Ad> setActive(Ad ad, bool active) async {
    _assertAdOwner(ad);
    final updated = ad.copyWith(isActive: active);

    if (_useMock) {
      final i = _mockAds.indexWhere((a) => a.id == ad.id);
      if (i != -1) _mockAds[i] = updated;
      revision.value++;
      return updated;
    }

    await FirebaseFirestore.instance
        .collection('ads')
        .doc(ad.id)
        .set({'isActive': active}, SetOptions(merge: true))
        .timeout(const Duration(seconds: 15));
    revision.value++;
    return updated;
  }

  /// حذف إعلان نهائياً — من صاحبه فقط
  Future<void> deleteAd(Ad ad) async {
    _assertAdOwner(ad);

    if (_useMock) {
      _mockAds.removeWhere((a) => a.id == ad.id);
      revision.value++;
      return;
    }

    await FirebaseFirestore.instance
        .collection('ads')
        .doc(ad.id)
        .delete()
        .timeout(const Duration(seconds: 15));
    revision.value++;
  }

  /// رفع صورة الإعلان على Supabase Storage (bucket: ad-images) ويرجّع
  /// رابطها العام. يرمي [InvalidImageException] لو الملف مرفوض.
  Future<String> uploadAdImage(String adOwnerId, XFile file) async {
    if (_useMock) {
      throw StateError('رفع الصور يحتاج التطبيق المنشور (مو وضع التجربة)');
    }
    final (ext, contentType, bytes) = await ImageValidation.validate(file);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return SupabaseStorageService.upload(
      bucket: 'ad-images',
      path: '$adOwnerId/$stamp.$ext',
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// حذف إعلان — مستنده ينحذف من Firestore فيختفي الإعلان وصورته من
  /// كل الشاشات. ملف الصورة نفسه يبقى بتخزين Supabase (ما عدنا سياسة
  /// حذف بمفتاح anon عمداً — شوف [SupabaseStorageService]).
  Future<void> deleteAdWithImage(Ad ad) => deleteAd(ad);

  /// كل إعلانات صاحب المنشأة عبر منشآته (نشيطة وموقوفة ومنتهية) — لشاشة
  /// "إعلاناتي" يديرها منها. الأحدث أولاً.
  Future<List<Ad>> myAds(List<String> fieldIds) async {
    if (fieldIds.isEmpty) return const [];

    List<Ad> list;
    if (_useMock) {
      list = _mockAds.where((a) => fieldIds.contains(a.fieldId)).toList();
    } else {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('ads')
            .where('fieldId', whereIn: fieldIds.take(10).toList())
            .get()
            .timeout(const Duration(seconds: 10));
        list = [
          for (final doc in snapshot.docs) Ad.fromMap(doc.id, doc.data()),
        ];
      } catch (_) {
        list = const [];
      }
    }
    list.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list;
  }

  /// الإعلانات النشطة (مفعّلة وغير منتهية) لمنشأة معيّنة — صفحة تفاصيلها
  Future<List<Ad>> activeAdsForField(String fieldId) async {
    final today = _today();
    List<Ad> list;
    if (_useMock) {
      list = _mockAds.where((a) => a.fieldId == fieldId).toList();
    } else {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('ads')
            .where('fieldId', isEqualTo: fieldId)
            .get()
            .timeout(const Duration(seconds: 10));
        list = [
          for (final doc in snapshot.docs) Ad.fromMap(doc.id, doc.data()),
        ];
      } catch (_) {
        list = const [];
      }
    }
    list = list.where((a) => a.isVisibleAt(today)).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list;
  }

  /// أحدث الإعلانات النشطة عبر كل التطبيق — قسم "العروض والإعلانات"
  /// بالرئيسية. الأحدث أولاً، والمنتهية لا تظهر إطلاقاً.
  Future<List<Ad>> activeAds({int limit = 20}) async {
    final today = _today();
    List<Ad> list;
    if (_useMock) {
      list = List.of(_mockAds);
    } else {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('ads')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAtMs', descending: true)
            .limit(limit * 2) // هامش حتى المنتهية اللي نفلترها ما تنقص العدد
            .get()
            .timeout(const Duration(seconds: 10));
        list = [
          for (final doc in snapshot.docs) Ad.fromMap(doc.id, doc.data()),
        ];
      } catch (_) {
        list = const [];
      }
    }
    list = list.where((a) => a.isVisibleAt(today)).toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return list.take(limit).toList();
  }

  /// تصفير وضع الاختبار — للاختبارات فقط
  @visibleForTesting
  void debugReset() {
    _mockAds.clear();
    revision.value++;
  }
}
