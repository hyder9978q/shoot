import 'package:shared_preferences/shared_preferences.dart';

import 'app_mode.dart';

/// خزن محلي خفيف (shared_preferences) — جلسة الدخول، الاسم، وتفضيل الوضع الليلي.
///
/// كل العمليات تتجاهل الأخطاء بهدوء: بالاختبارات الآلية ما في plugin
/// فنرجع القيم الافتراضية والتطبيق يكمل طبيعي.
class LocalStore {
  LocalStore._();

  static const String _kSignedIn = 'signed_in';
  static const String _kUserName = 'user_name';
  static const String _kThemeDark = 'theme_dark';
  static const String _kNotifyBookingConfirm = 'notify_booking_confirm';
  static const String _kNotifyReminder = 'notify_reminder';
  static const String _kNotifyPlayerRequests = 'notify_player_requests';

  static Future<SharedPreferences?> get _prefs async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// هل عنده جلسة دخول محفوظة؟
  ///
  /// معتمدة بوضع التجربة فقط ([AppMode.isMock]) — لأنها مجرد قيمة
  /// محفوظة بجهاز المستخدم وما تثبت شي بالسيرفر. بالإنتاج الحكم الوحيد
  /// هو حالة Firebase الحقيقية: لو انحذف الحساب أو انسحبت الجلسة
  /// (من لوحة Firebase مثلاً) يطلع المستخدم فوراً لشاشة الدخول بدل ما
  /// تبقى الجلسة سارية بجهازه على أساس علم محلي.
  static Future<bool> get signedIn async {
    if (!AppMode.isMock) return false;
    return (await _prefs)?.getBool(_kSignedIn) ?? false;
  }

  static Future<void> setSignedIn(bool value) async {
    await (await _prefs)?.setBool(_kSignedIn, value);
  }

  /// اسم المستخدم المحفوظ محلياً — فارغ إذا ما محفوظ
  static Future<String> get userName async =>
      (await _prefs)?.getString(_kUserName) ?? '';

  static Future<void> setUserName(String name) async {
    await (await _prefs)?.setString(_kUserName, name);
  }

  /// تفضيل الوضع الليلي — الافتراضي دائماً فاتح
  static Future<bool> get themeDark async =>
      (await _prefs)?.getBool(_kThemeDark) ?? false;

  static Future<void> setThemeDark(bool value) async {
    await (await _prefs)?.setBool(_kThemeDark, value);
  }

  /// تفضيلات الإشعارات — الافتراضي كله مفعّل. هسه بس نحفظ التفضيل
  /// (الإشعارات الفعلية بعدها ما مفعّلة بالتطبيق).
  static Future<bool> get notifyBookingConfirm async =>
      (await _prefs)?.getBool(_kNotifyBookingConfirm) ?? true;

  static Future<void> setNotifyBookingConfirm(bool value) async {
    await (await _prefs)?.setBool(_kNotifyBookingConfirm, value);
  }

  static Future<bool> get notifyReminder async =>
      (await _prefs)?.getBool(_kNotifyReminder) ?? true;

  static Future<void> setNotifyReminder(bool value) async {
    await (await _prefs)?.setBool(_kNotifyReminder, value);
  }

  static Future<bool> get notifyPlayerRequests async =>
      (await _prefs)?.getBool(_kNotifyPlayerRequests) ?? true;

  static Future<void> setNotifyPlayerRequests(bool value) async {
    await (await _prefs)?.setBool(_kNotifyPlayerRequests, value);
  }
}
