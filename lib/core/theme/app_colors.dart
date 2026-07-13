import 'package:flutter/material.dart';

/// لوحة ألوان كاملة — نسختان: نهارية وليلية
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.primaryDeep,
    required this.primaryLight,
    required this.ink,
    required this.grey,
    required this.muted,
    required this.background,
    required this.surface,
    required this.border,
    required this.hairline,
    required this.subtleFill,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.error,
    required this.errorSoft,
    required this.shadowAlpha,
  });

  final Color primary;
  final Color primaryDark;
  final Color primaryDeep;
  final Color primaryLight;
  final Color ink;

  /// نص ثانوي (#6B7280)
  final Color grey;

  /// نص خافت — تسميات وتفاصيل صغيرة (#9CA3AF)
  final Color muted;
  final Color background;
  final Color surface;
  final Color border;

  /// حد رفيع جداً بين عناصر القوائم (#F3F4F6)
  final Color hairline;
  final Color subtleFill;
  final Color accent;

  /// خلفية صفراء ناعمة للشارات (#FEF9C3)
  final Color accentSoft;

  /// نص على الخلفية الصفراء الناعمة (#A16207)
  final Color accentInk;
  final Color error;

  /// خلفية حمراء ناعمة (#FEE2E2)
  final Color errorSoft;
  final int shadowAlpha;
}

/// ألوان الهوية البصرية لتطبيق شوت (المرجع: DESIGN.md)
///
/// الألوان صارت getters تقرأ من اللوحة الحالية (نهارية/ليلية) —
/// التبديل عبر [setDark] ثم إعادة بناء الشجرة من الجذر.
class AppColors {
  AppColors._();

  /// اللوحة النهارية — مطابقة لنظام التصميم المعتمد
  static const AppPalette _light = AppPalette(
    primary: Color(0xFF16A34A),
    primaryDark: Color(0xFF15803D),
    primaryDeep: Color(0xFF166534),
    primaryLight: Color(0xFFDCFCE7),
    ink: Color(0xFF111827),
    grey: Color(0xFF6B7280),
    muted: Color(0xFF9CA3AF),
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE5E7EB),
    hairline: Color(0xFFF3F4F6),
    subtleFill: Color(0xFFF3F4F6),
    accent: Color(0xFFFACC15),
    accentSoft: Color(0xFFFEF9C3),
    accentInk: Color(0xFFA16207),
    error: Color(0xFFDC2626),
    errorSoft: Color(0xFFFEE2E2),
    shadowAlpha: 0x12,
  );

  static const AppPalette _darkPalette = AppPalette(
    primary: Color(0xFF22C55E),
    primaryDark: Color(0xFF4ADE80),
    primaryDeep: Color(0xFF86EFAC),
    primaryLight: Color(0xFF15301F),
    ink: Color(0xFFECF2EE),
    grey: Color(0xFF9DB0A5),
    muted: Color(0xFF7C8D83),
    background: Color(0xFF0E1411),
    surface: Color(0xFF1A231D),
    border: Color(0xFF2A362E),
    hairline: Color(0xFF232D26),
    subtleFill: Color(0xFF232D26),
    accent: Color(0xFFFACC15),
    accentSoft: Color(0xFF3A3115),
    accentInk: Color(0xFFFDE68A),
    error: Color(0xFFF87171),
    errorSoft: Color(0xFF3B1D1D),
    shadowAlpha: 0x33,
  );

  static AppPalette _p = _light;

  /// هل الوضع الليلي مفعّل؟
  static bool get isDark => identical(_p, _darkPalette);

  /// تبديل اللوحة — لازم يتبعها إعادة بناء كاملة (main.dart يتكفل)
  static void setDark(bool dark) => _p = dark ? _darkPalette : _light;

  static const AppPalette lightPalette = _light;
  static const AppPalette darkPalette = _darkPalette;

  /// الأخضر الرئيسي — يرمز للملاعب
  static Color get primary => _p.primary;

  /// درجات الأخضر للتدرجات وحالة الضغط
  static Color get primaryDark => _p.primaryDark;
  static Color get primaryDeep => _p.primaryDeep;
  static Color get primaryLight => _p.primaryLight;

  /// لون النص الأساسي (غامق نهاراً، فاتح ليلاً)
  static Color get dark => _p.ink;

  /// أبيض ثابت — للنصوص فوق الأخضر والخلفيات الغامقة (ما يتبدل)
  static const Color white = Color(0xFFFFFFFF);

  /// حبر ثابت غامق — لعناصر غامقة دائماً (اللعبة، أيقونة التطبيق)
  static const Color inkFixed = Color(0xFF111827);

  /// الأصفر — للتقييمات والعروض
  static Color get accent => _p.accent;

  /// نص ثانوي (#6B7280)
  static Color get grey => _p.grey;

  /// نص خافت — تسميات صغيرة ومسافات (#9CA3AF)
  static Color get muted => _p.muted;

  /// خلفية الصفحات
  static Color get background => _p.background;

  /// أسطح البطاقات والنماذج
  static Color get surface => _p.surface;
  static Color get border => _p.border;

  /// حد رفيع بين عناصر القوائم
  static Color get hairline => _p.hairline;

  /// تعبئة خفيفة — هياكل التحميل والعناصر المعطلة
  static Color get subtleFill => _p.subtleFill;

  /// شارات صفراء ناعمة (بانتظار الدفع، جديد...)
  static Color get accentSoft => _p.accentSoft;
  static Color get accentInk => _p.accentInk;
  static Color get error => _p.error;
  static Color get errorSoft => _p.errorSoft;

  /// ذهبي النجوم — الأصفر (accent) خفيف على الأبيض فما يقرأ بحجم النجمة
  /// الصغير، فالنجوم إلها درجة كهرمانية أوضح.
  static Color get star =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  /// خلفية خضراء ناعمة جداً — صناديق التقييم وأيقونات القوائم (#F0FDF4)
  static Color get primaryTint =>
      isDark ? _p.primaryLight : const Color(0xFFF0FDF4);

  /// خلفية بطاقات التقييم والصناديق الرمادية الفاتحة (#F8F9FA)
  static Color get panel => isDark ? _p.subtleFill : const Color(0xFFF8F9FA);

  /// تدرج الهوية — رؤوس الصفحات والسبلاش (ثابت بالوضعين: الأخضر هويتنا)
  static LinearGradient get brandGradient => const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [Color(0xFF16A34A), Color(0xFF0B5D2B)],
      );

  /// ظل البطاقات
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Color(_p.shadowAlpha << 24),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  /// ظل الزر الأخضر
  static List<BoxShadow> get primaryShadow => [
        BoxShadow(
          color: _p.primary.withValues(alpha: 0.16),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
