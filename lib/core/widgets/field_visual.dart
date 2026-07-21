import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/field.dart';

/// رسمة الملعب من الأعلى — الهوية البصرية لبطاقات الملاعب ورؤوس التفاصيل.
/// عشب أخضر متدرج مع خطوط الملعب حسب نوع الرياضة، بدون الحاجة لأي صور.
class FieldVisual extends StatelessWidget {
  const FieldVisual({super.key, required this.sport, this.borderRadius});

  final Sport sport;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CustomPaint(
        painter: _FieldVisualPainter(sport: sport),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FieldVisualPainter extends CustomPainter {
  const _FieldVisualPainter({required this.sport});

  final Sport sport;

  /// لونا الأرضية حسب نوع المكان — عشب، ماء، أو أرضية صالة
  List<Color> get _surface => switch (sport) {
    Sport.swimming => const [Color(0xFF22D3EE), Color(0xFF0B4A6F)],
    Sport.gym => const [Color(0xFF475569), Color(0xFF1E293B)],
    Sport.volleyball => const [Color(0xFFD97706), Color(0xFF7C3F0A)],
    Sport.therapy => const [Color(0xFF2DD4BF), Color(0xFF0F5C54)],
    _ => const [Color(0xFF16A34A), Color(0xFF0B5D2B)],
  };

  /// أشرطة قص العشب — بس للملاعب العشبية
  bool get _hasMowStripes => switch (sport) {
    Sport.swimming ||
    Sport.gym ||
    Sport.volleyball ||
    Sport.therapy => false,
    _ => true,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // الأرضية — ألوان ثابتة ما تتبدل بالوضع الليلي
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _surface,
        ).createShader(rect),
    );

    if (_hasMowStripes) {
      // أشرطة قص العشب العمودية
      final stripe = Paint()..color = Colors.white.withValues(alpha: 0.045);
      const bands = 8;
      final bandW = size.width / bands;
      for (var i = 0; i < bands; i += 2) {
        canvas.drawRect(
          Rect.fromLTWH(i * bandW, 0, bandW, size.height),
          stripe,
        );
      }
    }

    // خطوط الملعب
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.shortestSide * 0.014)
      ..color = Colors.white.withValues(alpha: 0.55);

    switch (sport) {
      case Sport.football:
      case Sport.sportsCentre:
        _football(canvas, size, line);
      case Sport.basketball:
        _basketball(canvas, size, line);
      case Sport.tennis:
      case Sport.padel:
        _racket(canvas, size, line, isPadel: sport == Sport.padel);
      case Sport.volleyball:
        _volleyball(canvas, size, line);
      case Sport.swimming:
        _pool(canvas, size, line);
      case Sport.gym:
        _gym(canvas, size, line);
      case Sport.therapy:
        _therapy(canvas, size, line);
    }

    // إضاءة خفيفة من الأعلى + تعتيم بسيط بالأسفل يعطي عمق
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.10),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  /// حدود الملعب المشتركة — مستطيل داخلي بهامش
  Rect _bounds(Size size) {
    final m = size.shortestSide * 0.13;
    return Rect.fromLTRB(m, m, size.width - m, size.height - m);
  }

  void _football(Canvas canvas, Size size, Paint line) {
    final b = _bounds(size);
    canvas.drawRect(b, line);

    // خط المنتصف + دائرة المنتصف
    canvas.drawLine(b.topCenter, b.bottomCenter, line);
    canvas.drawCircle(b.center, b.height * 0.22, line);
    canvas.drawCircle(b.center, line.strokeWidth, line..style = PaintingStyle.fill);
    line.style = PaintingStyle.stroke;

    // منطقة الجزاء ومنطقة المرمى على الجهتين
    for (final left in [true, false]) {
      final dx = left ? b.left : b.right;
      final sign = left ? 1.0 : -1.0;
      final penalty = Rect.fromCenter(
        center: Offset(dx + sign * b.width * 0.085, b.center.dy),
        width: b.width * 0.17,
        height: b.height * 0.58,
      );
      final goal = Rect.fromCenter(
        center: Offset(dx + sign * b.width * 0.035, b.center.dy),
        width: b.width * 0.07,
        height: b.height * 0.30,
      );
      canvas.drawRect(penalty, line);
      canvas.drawRect(goal, line);
    }

    // أقواس الزوايا
    final r = size.shortestSide * 0.05;
    canvas.drawArc(Rect.fromCircle(center: b.topLeft, radius: r), 0, math.pi / 2, false, line);
    canvas.drawArc(Rect.fromCircle(center: b.topRight, radius: r), math.pi / 2, math.pi / 2, false, line);
    canvas.drawArc(Rect.fromCircle(center: b.bottomRight, radius: r), math.pi, math.pi / 2, false, line);
    canvas.drawArc(Rect.fromCircle(center: b.bottomLeft, radius: r), -math.pi / 2, math.pi / 2, false, line);
  }

  void _basketball(Canvas canvas, Size size, Paint line) {
    final b = _bounds(size);
    canvas.drawRect(b, line);
    canvas.drawLine(b.topCenter, b.bottomCenter, line);
    canvas.drawCircle(b.center, b.height * 0.18, line);

    for (final left in [true, false]) {
      final dx = left ? b.left : b.right;
      final sign = left ? 1.0 : -1.0;
      // المفتاح (منطقة الرمية الحرة)
      final keyEnd = dx + sign * b.width * 0.24;
      final key = Rect.fromLTRB(
        math.min(dx, keyEnd),
        b.center.dy - b.height * 0.17,
        math.max(dx, keyEnd),
        b.center.dy + b.height * 0.17,
      );
      canvas.drawRect(key, line);
      // دائرة الرمية الحرة
      canvas.drawCircle(Offset(keyEnd, b.center.dy), b.height * 0.13, line);
      // قوس الثلاث نقاط
      final arcR = b.height * 0.44;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(dx, b.center.dy), radius: arcR),
        left ? -math.pi / 2 : math.pi / 2,
        math.pi,
        false,
        line,
      );
    }
  }

  void _racket(Canvas canvas, Size size, Paint line, {required bool isPadel}) {
    final b = _bounds(size);
    canvas.drawRect(b, line);

    // خطوط الفردي (تنس) أو هامش الجدران (بادل)
    final inset = b.height * (isPadel ? 0.0 : 0.14);
    final top = b.top + inset;
    final bottom = b.bottom - inset;
    if (!isPadel) {
      canvas.drawLine(Offset(b.left, top), Offset(b.right, top), line);
      canvas.drawLine(Offset(b.left, bottom), Offset(b.right, bottom), line);
    }

    // خطا الإرسال + خط الوسط بينهما
    final serveOffset = b.width * (isPadel ? 0.30 : 0.22);
    final s1 = b.center.dx - serveOffset;
    final s2 = b.center.dx + serveOffset;
    canvas.drawLine(Offset(s1, top), Offset(s1, bottom), line);
    canvas.drawLine(Offset(s2, top), Offset(s2, bottom), line);
    canvas.drawLine(
      Offset(s1, b.center.dy),
      Offset(s2, b.center.dy),
      line,
    );

    // الشبكة — خط أوضح بالمنتصف
    final net = Paint()
      ..strokeWidth = line.strokeWidth * 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawLine(b.topCenter, b.bottomCenter, net);
  }

  /// ملعب الطائرة — شبكة بالمنتصف وخطا الهجوم
  void _volleyball(Canvas canvas, Size size, Paint line) {
    final b = _bounds(size);
    canvas.drawRect(b, line);

    // خطا الهجوم على جهتي الشبكة
    for (final sign in [-1.0, 1.0]) {
      final dx = b.center.dx + sign * b.width * 0.17;
      canvas.drawLine(Offset(dx, b.top), Offset(dx, b.bottom), line);
    }

    // الشبكة — خط أعرض مع أعمدة
    final net = Paint()
      ..strokeWidth = line.strokeWidth * 1.8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.80);
    canvas.drawLine(b.topCenter, b.bottomCenter, net);
    final postR = line.strokeWidth * 1.6;
    final post = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(b.topCenter, postR, post);
    canvas.drawCircle(b.bottomCenter, postR, post);
  }

  /// المسبح — مسارات سباحة بحبال فاصلة وحافة فاتحة
  void _pool(Canvas canvas, Size size, Paint line) {
    final b = _bounds(size);

    // حافة المسبح
    final deck = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 2.4
      ..color = Colors.white.withValues(alpha: 0.30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(b, Radius.circular(size.shortestSide * 0.04)),
      deck,
    );

    // حبال المسارات — أفقية عبر طول المسبح
    const lanes = 5;
    final laneH = b.height / lanes;
    final rope = Paint()
      ..strokeWidth = line.strokeWidth * 0.9
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.45);
    for (var i = 1; i < lanes; i++) {
      final dy = b.top + i * laneH;
      canvas.drawLine(Offset(b.left, dy), Offset(b.right, dy), rope);
    }

    // خط النهاية بكل مسار — علامة قصيرة على الحافتين
    final mark = Paint()
      ..strokeWidth = line.strokeWidth * 1.6
      ..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < lanes; i++) {
      final dy = b.top + (i + 0.5) * laneH;
      canvas.drawLine(
        Offset(b.left, dy),
        Offset(b.left + b.width * 0.06, dy),
        mark,
      );
      canvas.drawLine(
        Offset(b.right - b.width * 0.06, dy),
        Offset(b.right, dy),
        mark,
      );
    }
  }

  /// النادي الرياضي — حديد (بار بأثقال) على أرضية الصالة
  void _gym(Canvas canvas, Size size, Paint line) {
    final b = _bounds(size);
    final c = b.center;
    final barW = b.width * 0.62;
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.70);

    // البار
    canvas.drawLine(
      Offset(c.dx - barW / 2, c.dy),
      Offset(c.dx + barW / 2, c.dy),
      Paint()
        ..strokeWidth = line.strokeWidth * 1.3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.70),
    );

    // الأثقال — قرصين بكل جهة
    final plateH = b.height * 0.42;
    final plateW = b.width * 0.045;
    for (final sign in [-1.0, 1.0]) {
      for (final (i, scale) in [1.0, 0.66].indexed) {
        final dx = c.dx + sign * (barW / 2 - plateW * (0.6 + i * 1.6));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(dx, c.dy),
              width: plateW,
              height: plateH * scale,
            ),
            Radius.circular(plateW * 0.35),
          ),
          fill,
        );
      }
    }
  }

  /// مركز العلاج — سرير علاج (تخت مساج) وصليب طبي بزاوية الغرفة
  void _therapy(Canvas canvas, Size size, Paint line) {
    final b = _bounds(size);
    final c = b.center;

    // حدود الغرفة
    canvas.drawRRect(
      RRect.fromRectAndRadius(b, Radius.circular(size.shortestSide * 0.04)),
      line,
    );

    // سرير العلاج — مستطيل بوسادة بالمنتصف
    final bed = Rect.fromCenter(
      center: c,
      width: b.width * 0.44,
      height: b.height * 0.34,
    );
    final bedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 1.3
      ..color = Colors.white.withValues(alpha: 0.70);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bed, Radius.circular(bed.height * 0.22)),
      bedPaint,
    );
    // الوسادة
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bed.left + bed.width * 0.16, c.dy),
          width: bed.width * 0.18,
          height: bed.height * 0.56,
        ),
        Radius.circular(bed.height * 0.12),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // صليب طبي بأعلى الزاوية
    final crossC = Offset(
      b.right - b.width * 0.13,
      b.top + b.height * 0.2,
    );
    final arm = size.shortestSide * 0.052;
    final thickness = arm * 0.62;
    final cross = Paint()..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: crossC, width: arm * 2, height: thickness),
        Radius.circular(thickness * 0.3),
      ),
      cross,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: crossC, width: thickness, height: arm * 2),
        Radius.circular(thickness * 0.3),
      ),
      cross,
    );
  }

  @override
  bool shouldRepaint(covariant _FieldVisualPainter oldDelegate) =>
      oldDelegate.sport != sport;
}
