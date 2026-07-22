/// تسميات التواريخ بالعربي — بدون الحاجة لتهيئة intl
class DateLabels {
  DateLabels._();

  /// للاختبارات: تثبيت "الآن" حتى ما تتغير التواريخ بين تشغيلة وأخرى
  static DateTime? debugNow;

  /// أيام الأسبوع حسب DateTime.weekday (1 = الاثنين)
  static const List<String> weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  /// تاريخ بصيغة yyyy-MM-dd بعد [daysFromNow] يوم من اليوم
  static String dateFor(int daysFromNow) {
    final d = (debugNow ?? DateTime.now()).add(Duration(days: daysFromNow));
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// تسمية ودّية للتاريخ: اليوم / باچر / الأربعاء 15/7
  static String label(String date) {
    if (date == dateFor(0)) return 'اليوم';
    if (date == dateFor(1)) return 'باچر';
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return '${weekdays[parsed.weekday - 1]} ${parsed.day}/${parsed.month}';
  }

  /// تسمية قصيرة لشيبس اختيار اليوم: اليوم / باچر / الأربعاء
  static String shortLabel(String date) {
    if (date == dateFor(0)) return 'اليوم';
    if (date == dateFor(1)) return 'باچر';
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return weekdays[parsed.weekday - 1];
  }

  /// اليوم/الشهر للعرض تحت اسم اليوم (مثال: 15/7)
  static String dayMonth(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    return '${parsed.day}/${parsed.month}';
  }

  /// اسم اليوم مختصر لمخطط الأرباح: إثن / ثلا / أرب ...
  static String weekdayShort(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return '';
    const short = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];
    return short[parsed.weekday - 1];
  }

  /// أول يوم بالشهر الحالي بصيغة yyyy-MM-dd — لحساب "هذا الشهر" بترتيب الحي
  static String monthStart() {
    final d = debugNow ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    return '${d.year}-$m-01';
  }

  /// نص "عضو منذ..." من وقت إنشاء الحساب بالميلي ثانية
  static String membershipLabel(int joinedAtMs) {
    final now = debugNow ?? DateTime.now();
    final joined = DateTime.fromMillisecondsSinceEpoch(joinedAtMs);
    final days = now.difference(joined).inDays;
    if (days < 1) return 'عضو اليوم';
    if (days < 30) return 'عضو منذ $days يوم';
    if (days < 365) return 'عضو منذ ${days ~/ 30} شهر';
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    if (months == 0) return 'عضو منذ $years سنة';
    return 'عضو منذ $years سنة و$months شهر';
  }
}
