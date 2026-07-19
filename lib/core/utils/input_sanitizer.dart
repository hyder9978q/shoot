import 'package:flutter/services.dart';

/// تنظيف المدخلات — خط دفاع على مستوى التطبيق
/// يمنع الرموز الخطيرة (حقن كود / SQL) ويحدّ أطوال النصوص.
class InputSanitizer {
  InputSanitizer._();

  /// رموز خطيرة ما نسمح بيها بالنصوص: وسوم، اقتباسات، فواصل أوامر...
  static final RegExp _dangerous = RegExp(r'''[<>{}\[\]\\`$;"'=%&|^~]''');

  /// محارف تحكم غير مرئية
  static final RegExp _control = RegExp(r'[\x00-\x1F\x7F]');

  /// الحد الأقصى لطول الاسم
  static const int nameMaxLength = 50;

  /// فلتر للحقول — يمنع كتابة الرموز الخطيرة من الأساس
  static TextInputFormatter deny() =>
      FilteringTextInputFormatter.deny(_dangerous);

  /// تنظيف نص عام: يشيل محارف التحكم والرموز الخطيرة ويقص الطول
  static String clean(String input, {int maxLength = 200}) {
    var s = input.replaceAll(_control, '').replaceAll(_dangerous, '').trim();
    if (s.length > maxLength) s = s.substring(0, maxLength).trim();
    return s;
  }

  /// اسم صالح؟ غير فارغ، ٥٠ حرف كحد أقصى، بدون رموز خطيرة
  static bool isValidName(String name) {
    final t = name.trim();
    return t.isNotEmpty &&
        t.length <= nameMaxLength &&
        !_dangerous.hasMatch(t) &&
        !_control.hasMatch(t);
  }
}
