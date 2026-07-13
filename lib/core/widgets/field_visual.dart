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

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // أرضية العشب — أخضر الهوية الثابت (ما يتبدل بالوضع الليلي)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16A34A), Color(0xFF0B5D2B)],
        ).createShader(rect),
    );

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

    // خطوط الملعب
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, size.shortestSide * 0.014)
      ..color = Colors.white.withValues(alpha: 0.55);

    switch (sport) {
      case Sport.football:
        _football(canvas, size, line);
      case Sport.basketball:
        _basketball(canvas, size, line);
      case Sport.tennis:
      case Sport.padel:
        _racket(canvas, size, line, isPadel: sport == Sport.padel);
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

  @override
  bool shouldRepaint(covariant _FieldVisualPainter oldDelegate) =>
      oldDelegate.sport != sport;
}
