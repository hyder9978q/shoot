import 'arabic_num.dart';

/// تنسيق وقت الحجز للعرض بنظام ١٢ ساعة وأرقام عربية-هندية (٦:٠٠ مساءً)
/// بدل نظام ٢٤ ساعة (18:00).
///
/// هذا للعرض بس — التخزين الداخلي ومنطق الحجز ومنع الحجز المزدوج يبقون
/// يشتغلون بنظام ٢٤ ساعة (نفس الـ int) بدون أي تغيير.
class TimeLabels {
  TimeLabels._();

  /// وقت نقطة وحدة: 18 → ٦:٠٠ مساءً، 9 → ٩:٠٠ صباحاً، 24 (منتصف الليل
  /// كساعة إغلاق) → ١٢:٠٠ صباحاً
  static String hour12(int hour) {
    final normalized = hour % 24;
    final period = normalized < 12 ? 'صباحاً' : 'مساءً';
    var h = normalized % 12;
    if (h == 0) h = 12;
    return '${ArabicNum.count(h)}:٠٠ $period';
  }

  /// مدى ساعة كاملة: 18 → ٦:٠٠ مساءً - ٧:٠٠ مساءً
  static String hourRange12(int startHour) =>
      '${hour12(startHour)} - ${hour12(startHour + 1)}';
}
