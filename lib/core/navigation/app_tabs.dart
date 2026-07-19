import 'package:flutter/foundation.dart';

/// متحكّم التبويبات السفلية — يخلي أي شاشة تگدر تنقل المستخدم لتبويب ثاني
/// (مثلاً زر "تصفّح الملاعب" بالحالات الفارغة ينقله لتبويب الرئيسية).
class AppTabs {
  AppTabs._();

  /// أرقام التبويبات: 0 الرئيسية، 1 حجوزاتي، 2 ناقصنا لاعب، 3 حسابي
  static const int home = 0;
  static const int bookings = 1;
  static const int players = 2;
  static const int profile = 3;

  /// التبويب الحالي — [MainShell] يسمعه ويعيد البناء
  static final ValueNotifier<int> current = ValueNotifier<int>(home);

  /// انقل لتبويب معيّن
  static void go(int index) => current.value = index;
}
