import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../theme/theme_controller.dart';
import '../utils/input_sanitizer.dart';
import 'local_store.dart';

/// ملف المستخدم — الاسم والمفضلة، ينخزن بمستند users/{uid}
/// وبوضع الاختبار (بدون Firebase) يشتغل بالذاكرة.
class UserService {
  UserService._();

  static final UserService instance = UserService._();

  /// يتحدث مع أي تغيير (اسم/مفضلة) — الشاشات تسمعه وتحدث نفسها
  final ValueNotifier<int> revision = ValueNotifier(0);

  String _name = '';
  final Set<String> _favorites = {};
  bool _loaded = false;

  bool get _useMock => Firebase.apps.isEmpty;

  String get _uid => _useMock
      ? 'mock-user'
      : FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  /// اسم المستخدم — فارغ إذا بعده ما عرّف نفسه
  String get name => _name;

  bool isFavorite(String fieldId) => _favorites.contains(fieldId);

  List<String> get favoriteIds => _favorites.toList();

  /// تحميل الملف مرة وحدة بعد تسجيل الدخول
  ///
  /// الوضع الليلي ما ينقرأ من هنا: تفضيل الثيم محلي فقط
  /// (ينحمّل بالإقلاع من [ThemeController.loadSaved]) حتى ما يطلع
  /// الدارك بالغلط من بيانات قديمة بالسيرفر.
  Future<void> load() async {
    if (_loaded) return;
    if (_useMock) {
      // بالوضع التجريبي: الاسم محفوظ محلياً حتى الجلسة تثبت بعد إعادة الفتح
      _name = await LocalStore.userName;
      _loaded = true;
      revision.value++;
      return;
    }
    try {
      final snapshot = await _doc.get().timeout(const Duration(seconds: 10));
      final data = snapshot.data();
      _name = (data?['name'] as String?) ?? '';
      _favorites
        ..clear()
        ..addAll(
          ((data?['favoriteFieldIds'] as List?) ?? const []).cast<String>(),
        );
    } catch (_) {
      // بدون نت: نرجع للاسم المحفوظ محلياً — التطبيق يشتغل طبيعي
      if (_name.isEmpty) _name = await LocalStore.userName;
    }
    _loaded = true;
    revision.value++;
  }

  /// حفظ اسم جاري؟ — ما نكتب مرتين بنفس الوقت
  bool _savingName = false;

  Future<void> saveName(String name) async {
    if (_savingName) return;
    // تنظيف الاسم: بدون رموز خطيرة وبحد أقصى ٥٠ حرف
    _name = InputSanitizer.clean(
      name,
      maxLength: InputSanitizer.nameMaxLength,
    );
    revision.value++;
    // نسخة محلية من الاسم حتى الدخول المثبّت محلياً يفوت مباشرة
    await LocalStore.setUserName(_name);
    if (_useMock) return;

    _savingName = true;
    try {
      await _doc.set({
        'name': _name,
        'phone': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
    } finally {
      _savingName = false;
    }
  }

  /// حفظ تفضيل الوضع الليلي — يطبقه فوراً ويخزنه محلياً فقط
  /// (اختيار المستخدم هو المصدر الوحيد، ما نتبع النظام ولا السيرفر)
  Future<void> saveThemeDark(bool dark) async {
    await ThemeController.instance.saveDark(dark);
  }

  /// تبديلات مفضلة جارية (بمعرّف الملعب) — الضغط المتكرر السريع
  /// ما يرسل كتابتين متسابقتين على نفس الملعب
  final Set<String> _togglingFavorites = {};

  /// إضافة/إزالة ملعب من المفضلة — تحديث متفائل مع تراجع عند الفشل
  Future<void> toggleFavorite(String fieldId) async {
    if (!_useMock && !_togglingFavorites.add(fieldId)) return;
    final adding = !_favorites.contains(fieldId);
    adding ? _favorites.add(fieldId) : _favorites.remove(fieldId);
    revision.value++;
    if (_useMock) return;

    try {
      await _doc.set({
        'favoriteFieldIds': adding
            ? FieldValue.arrayUnion([fieldId])
            : FieldValue.arrayRemove([fieldId]),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
    } catch (_) {
      // فشل الحفظ: نرجّع الحالة مثل ما كانت
      adding ? _favorites.remove(fieldId) : _favorites.add(fieldId);
      revision.value++;
    } finally {
      _togglingFavorites.remove(fieldId);
    }
  }

  /// تنظيف الحالة عند تسجيل الخروج
  void resetForSignOut() {
    _name = '';
    _favorites.clear();
    _loaded = false;
    LocalStore.setUserName('');
    revision.value++;
  }
}
