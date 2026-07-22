import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/theme_controller.dart';
import '../utils/input_sanitizer.dart';
import 'local_store.dart';
import 'supabase_storage_service.dart';

/// صورة غير صالحة (امتداد مرفوض أو حجم أكبر من الحد)
class InvalidPhotoException implements Exception {
  const InvalidPhotoException({required this.tooLarge});

  final bool tooLarge;
}

/// ملف المستخدم — الاسم والمدينة والصورة والمفضلة، ينخزن بمستند users/{uid}
/// وبوضع الاختبار (بدون Firebase) يشتغل بالذاكرة.
///
/// الاسم والمدينة والصورة ووقت الانضمام تنكتب أيضاً بنسخة عامة آمنة
/// بمجموعة players/{uid} — منها تُقرأ ملفات اللاعبين الثانين وترتيب
/// الحي بدون ما نكشف رقم الهاتف أو المفضلة (تبقى بمستند users الخاص).
class UserService {
  UserService._();

  static final UserService instance = UserService._();

  /// يتحدث مع أي تغيير (اسم/مدينة/صورة/مفضلة) — الشاشات تسمعه وتحدث نفسها
  final ValueNotifier<int> revision = ValueNotifier(0);

  String _name = '';
  String _city = '';
  String _photoUrl = '';
  int? _joinedAtMs;
  final Set<String> _favorites = {};
  bool _loaded = false;

  bool get _useMock => Firebase.apps.isEmpty;

  String get _uid =>
      _useMock ? 'mock-user' : FirebaseAuth.instance.currentUser?.uid ?? '';

  /// معرّف المستخدم الحالي — يستخدمه أي مكان يحتاج يقارن "هذا ملفي انا؟"
  String get uid => _uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  DocumentReference<Map<String, dynamic>> get _publicDoc =>
      FirebaseFirestore.instance.collection('players').doc(_uid);

  /// اسم المستخدم — فارغ إذا بعده ما عرّف نفسه
  String get name => _name;

  /// مدينة اللاعب — فارغة إذا بعده ما حددها (ترتيب الحي يحتاجها)
  String get city => _city;

  /// رابط صورة الملف الشخصي — فارغ = تنعرض حرف الاسم الأول بدلها
  String get photoUrl => _photoUrl;

  /// وقت إنشاء الحساب بالميلي ثانية — null لين ما يتحمّل الملف
  int? get joinedAtMs => _joinedAtMs;

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
      // ماكو سيرفر بالتجربة — مدة العضوية تبدي من هسه
      _joinedAtMs = DateTime.now().millisecondsSinceEpoch;
      _loaded = true;
      revision.value++;
      return;
    }
    try {
      final snapshot = await _doc.get().timeout(const Duration(seconds: 10));
      final data = snapshot.data();
      _name = (data?['name'] as String?) ?? '';
      _city = (data?['city'] as String?) ?? '';
      _photoUrl = (data?['photoUrl'] as String?) ?? '';
      _favorites
        ..clear()
        ..addAll(
          ((data?['favoriteFieldIds'] as List?) ?? const []).cast<String>(),
        );

      final createdAt = data?['createdAt'];
      if (createdAt is Timestamp) {
        _joinedAtMs = createdAt.millisecondsSinceEpoch;
      } else {
        // أول دخول (أو حساب قديم قبل هالميزة): نسجّل بداية العضوية الآن
        // مرة وحدة — قواعد الحماية تمنع تغييرها بعدين.
        _joinedAtMs = DateTime.now().millisecondsSinceEpoch;
        try {
          await _doc
              .set({
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10));
          await _publicDoc
              .set({
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          // فشل التسجيل ما يكسر التحميل — نحاول مرة ثانية بأول تحميل جاي
        }
      }
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
    _name = InputSanitizer.clean(name, maxLength: InputSanitizer.nameMaxLength);
    revision.value++;
    // نسخة محلية من الاسم حتى الدخول المثبّت محلياً يفوت مباشرة
    await LocalStore.setUserName(_name);
    if (_useMock) return;

    _savingName = true;
    try {
      await _doc
          .set({
            'name': _name,
            'phone': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      await _mirrorPublic({'name': _name});
    } finally {
      _savingName = false;
    }
  }

  /// حفظ مدينة جاري؟ — ما نكتب مرتين بنفس الوقت
  bool _savingCity = false;

  /// حفظ مدينة اللاعب — تظهر بملفه وتُستخدم لترتيب الحي
  Future<void> saveCity(String city) async {
    if (_savingCity) return;
    _city = InputSanitizer.clean(city, maxLength: 30);
    revision.value++;
    if (_useMock) return;

    _savingCity = true;
    try {
      await _doc
          .set({
            'city': _city,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      await _mirrorPublic({'city': _city});
    } finally {
      _savingCity = false;
    }
  }

  /// حفظ رابط صورة جاري؟
  bool _savingPhoto = false;

  Future<void> _savePhotoUrl(String url) async {
    final old = _photoUrl;
    _photoUrl = url;
    revision.value++;
    if (_useMock) return;

    try {
      await _doc
          .set({
            'photoUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
      await _mirrorPublic({'photoUrl': url});
    } catch (_) {
      _photoUrl = old;
      revision.value++;
      rethrow;
    }
  }

  /// امتدادات صور مقبولة لصورة الملف الشخصي (بنفس حدود صور الملاعب)
  static const Map<String, String> _allowedPhotoTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const int maxPhotoBytes = 5 * 1024 * 1024;

  /// رفع الصور معطّل بوضع التجربة (بدون Firebase منشور)
  static bool get canUploadPhoto => Firebase.apps.isNotEmpty;

  /// يختار صورة من المعرض ويرفعها ويحفظ رابطها — يرمي [InvalidPhotoException]
  /// لو الامتداد مرفوض أو الحجم أكبر من ٥ ميغا
  Future<void> pickAndUploadPhoto() async {
    if (_savingPhoto) return;
    if (!canUploadPhoto) {
      throw StateError('رفع الصور يحتاج التطبيق المنشور (مو وضع التجربة)');
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;

    _savingPhoto = true;
    try {
      final dot = file.name.lastIndexOf('.');
      final ext = dot == -1 ? '' : file.name.substring(dot + 1).toLowerCase();
      if (!_allowedPhotoTypes.containsKey(ext)) {
        throw const InvalidPhotoException(tooLarge: false);
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > maxPhotoBytes) {
        throw const InvalidPhotoException(tooLarge: true);
      }

      final stamp = DateTime.now().microsecondsSinceEpoch;
      final url = await SupabaseStorageService.upload(
        bucket: 'player-photos',
        path: '$_uid/$stamp.$ext',
        bytes: bytes,
        contentType: _allowedPhotoTypes[ext]!,
      );
      await _savePhotoUrl(url);
    } finally {
      _savingPhoto = false;
    }
  }

  /// كتابة نسخة عامة آمنة بمجموعة players — بأفضل جهد (فشلها ما يكسر
  /// الحفظ الأساسي بمستند users الخاص)
  Future<void> _mirrorPublic(Map<String, Object?> fields) async {
    try {
      await _publicDoc
          .set(fields, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // ملفي الخاص انحفظ بنجاح — النسخة العامة تتحدث بمحاولة جايه
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
      await _doc
          .set({
            'favoriteFieldIds': adding
                ? FieldValue.arrayUnion([fieldId])
                : FieldValue.arrayRemove([fieldId]),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
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
    _city = '';
    _photoUrl = '';
    _joinedAtMs = null;
    _favorites.clear();
    _loaded = false;
    LocalStore.setUserName('');
    revision.value++;
  }
}
