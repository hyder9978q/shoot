import 'package:flutter/foundation.dart';

/// متحكّم التبويبات السفلية لحساب صاحب المنشأة — منفصل عن [AppTabs]
/// الخاص بحساب اللاعب، حتى ما يتشارك الاثنين نفس الحالة.
class OwnerTabs {
  OwnerTabs._();

  /// أرقام التبويبات: 0 لوحة التحكم، 1 الحجوزات، 2 منشآتي، 3 إعلاناتي،
  /// 4 الإعدادات
  static const int dashboard = 0;
  static const int bookings = 1;
  static const int venues = 2;
  static const int ads = 3;
  static const int settings = 4;

  /// التبويب الحالي — [OwnerShell] يسمعه ويعيد البناء
  static final ValueNotifier<int> current = ValueNotifier<int>(dashboard);

  /// انقل لتبويب معيّن
  static void go(int index) => current.value = index;
}
