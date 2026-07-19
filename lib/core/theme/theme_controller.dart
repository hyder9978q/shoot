import 'package:flutter/foundation.dart';

import '../services/local_store.dart';
import 'app_colors.dart';

/// متحكم الوضع الليلي — يبدّل اللوحة ويخبر جذر التطبيق ليعيد البناء.
///
/// الوضع الفاتح هو الافتراضي المضمون بكل فتح/تحديث. ما نتبع وضع النظام:
/// الليلي يتفعّل فقط إذا المستخدم اختاره بنفسه، واختياره ينحفظ محلياً.
class ThemeController {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  /// true = الوضع الليلي
  final ValueNotifier<bool> isDark = ValueNotifier(false);

  void setDark(bool dark) {
    if (isDark.value == dark) return;
    AppColors.setDark(dark);
    isDark.value = dark;
  }

  /// تحميل الاختيار المحفوظ محلياً عند الإقلاع — إذا ماكو اختيار: فاتح
  Future<void> loadSaved() async {
    setDark(await LocalStore.themeDark);
  }

  /// تطبيق اختيار المستخدم وحفظه محلياً
  Future<void> saveDark(bool dark) async {
    setDark(dark);
    await LocalStore.setThemeDark(dark);
  }
}
