/// تنسيق الأرقام بالأرقام العربية-الهندية حسب نظام التصميم
/// (الأسعار والأعداد: ٢٥٬٠٠٠ — أوقات الحجز تُنسّق عبر [TimeLabels] بنظام
/// ١٢ ساعة وأرقام عربية-هندية بالضبط، انظر lib/core/utils/time_labels.dart)
class ArabicNum {
  ArabicNum._();

  static const List<String> _digits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  /// تحويل أي نص فيه أرقام لاتينية إلى أرقام عربية-هندية
  static String convert(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      final code = rune - 48;
      buffer.write(code >= 0 && code <= 9 ? _digits[code] : c);
    }
    return buffer.toString();
  }

  /// عدد بفاصلة آلاف عربية: 25000 → ٢٥٬٠٠٠
  static String money(int value) {
    final raw = value.abs().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) grouped.write('٬');
      grouped.write(_digits[raw.codeUnitAt(i) - 48]);
    }
    return '${value < 0 ? '-' : ''}$grouped';
  }

  /// عدد بسيط: 124 → ١٢٤
  static String count(num value) => convert(value.toString());
}
