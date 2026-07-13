import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../theme/theme_controller.dart';

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
  Future<void> load() async {
    if (_loaded) return;
    if (_useMock) {
      _loaded = true;
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
      // تفضيل الوضع الليلي المحفوظ
      ThemeController.instance.setDark(
        (data?['themeDark'] as bool?) ?? false,
      );
      revision.value++;
    } catch (_) {
      // بدون نت: نكمل بدون ملف — التطبيق يشتغل طبيعي
    }
    _loaded = true;
  }

  Future<void> saveName(String name) async {
    _name = name.trim();
    revision.value++;
    if (_useMock) return;

    await _doc.set({
      'name': _name,
      'phone': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 15));
  }

  /// حفظ تفضيل الوضع الليلي (يطبقه فوراً ويخزنه بالملف)
  Future<void> saveThemeDark(bool dark) async {
    ThemeController.instance.setDark(dark);
    if (_useMock) return;
    try {
      await _doc.set({'themeDark': dark}, SetOptions(merge: true)).timeout(
            const Duration(seconds: 15),
          );
    } catch (_) {
      // فشل الحفظ ما يلغي التبديل المحلي
    }
  }

  /// إضافة/إزالة ملعب من المفضلة — تحديث متفائل مع تراجع عند الفشل
  Future<void> toggleFavorite(String fieldId) async {
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
    }
  }

  /// تنظيف الحالة عند تسجيل الخروج
  void resetForSignOut() {
    _name = '';
    _favorites.clear();
    _loaded = false;
    revision.value++;
  }
}
