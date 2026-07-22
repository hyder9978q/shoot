import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// وضع التجربة (بيانات تجريبية بالذاكرة بدل Firebase حقيقي، ورمز تحقق
/// ثابت 123456) — يشتغل بس بوضع التطوير (تصحيح الأخطاء) أو الاختبارات.
///
/// ببناء الإنتاج (release) ما يشتغل إطلاقاً حتى لو فشلت تهيئة Firebase
/// لأي سبب — التطبيق يرفض الدخول ويعرض خطأ بدل ما يقبل حساب وهمي.
/// [kDebugMode] ثابت وقت الترجمة: true بوضع التطوير و[flutter test]،
/// و false حصراً ببناء release/profile — ما يگدر أي مستخدم يبدّله.
class AppMode {
  AppMode._();

  static bool get isMock => kDebugMode && Firebase.apps.isEmpty;
}
