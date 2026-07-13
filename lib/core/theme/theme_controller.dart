import 'package:flutter/foundation.dart';

import 'app_colors.dart';

/// متحكم الوضع الليلي — يبدّل اللوحة ويخبر جذر التطبيق ليعيد البناء.
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
}
