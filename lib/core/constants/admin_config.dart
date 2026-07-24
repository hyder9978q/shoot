import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/app_mode.dart';

/// معرّفات حسابات المسؤولين (admin UIDs) — نفس القائمة لازم تنطابق مع
/// القائمة المكتوبة بقواعد Firestore (firestore.rules دالة isAdmin())
/// حتى لوحة الإدارة تشتغل وتقدر تقرأ وتعدّل بيانات الاقتراحات فعلياً.
///
/// لإضافة حسابك: افتح التطبيق وسجّل دخولك، بعدين شوف معرّف حسابك (UID)
/// من Firebase Console → Authentication → Users (عمود User UID)، أو
/// اطبعه مؤقتاً بالكود بـ FirebaseAuth.instance.currentUser?.uid.
/// انسخه وضيفه هنا وبنفس الوقت بقائمة isAdmin() بملف firestore.rules،
/// وبعدين انشر القواعد من جديد (firebase deploy --only firestore:rules).
const Set<String> adminUids = {
  'zbILiMg4wVVmVdKjM6Z4YXwTuW52', // +9647701234567
};

/// هل المستخدم الحالي مسؤول؟ — يتحكم بظهور لوحة إدارة اقتراحات الملاعب
class AdminConfig {
  AdminConfig._();

  /// يفرض قيمة معيّنة بالاختبارات — بدونه الفحص الحقيقي (UID بقائمة
  /// adminUids) هو المعتمد حتى بوضع التجربة
  @visibleForTesting
  static bool? debugIsAdmin;

  static bool get isCurrentUserAdmin {
    if (debugIsAdmin != null) return debugIsAdmin!;
    final uid = AppMode.isMock
        ? 'mock-user'
        : FirebaseAuth.instance.currentUser?.uid;
    return uid != null && adminUids.contains(uid);
  }
}
