import 'package:shared_preferences/shared_preferences.dart';

/// خزن محلي خفيف (shared_preferences) — جلسة الدخول، الاسم، وتفضيل الوضع الليلي.
///
/// كل العمليات تتجاهل الأخطاء بهدوء: بالاختبارات الآلية ما في plugin
/// فنرجع القيم الافتراضية والتطبيق يكمل طبيعي.
class LocalStore {
  LocalStore._();

  static const String _kSignedIn = 'signed_in';
  static const String _kUserName = 'user_name';
  static const String _kThemeDark = 'theme_dark';

  static Future<SharedPreferences?> get _prefs async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// هل عنده جلسة دخول محفوظة؟
  static Future<bool> get signedIn async =>
      (await _prefs)?.getBool(_kSignedIn) ?? false;

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
}
