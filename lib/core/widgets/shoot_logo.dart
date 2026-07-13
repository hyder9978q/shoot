import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// شعار شوت — كرة قدم مرسومة يدوياً مع خطوط سرعة (التسديدة)
/// نفس الرسمة تُستخدم بالسبلاش وتسجيل الدخول وأيقونة التطبيق.
class ShootMark extends StatelessWidget {
  const ShootMark({super.key, required this.size, this.showTrail = false});

  final double size;

  /// خطوط السرعة الصفراء خلف الكرة
  final bool showTrail;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ShootMarkPainter(showTrail: showTrail),
    );
  }
}

class _ShootMarkPainter extends CustomPainter {
  const _ShootMarkPainter({required this.showTrail});

  final bool showTrail;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    if (showTrail) {
      // الكرة بالربع الأعلى الأمامي وخطوط السرعة خلفها (تسديدة نحو الزاوية)
      final ballCenter = Offset(s * 0.60, s * 0.40);
      final ballRadius = s * 0.30;
      _paintTrail(canvas, s, ballCenter, ballRadius);
      _paintBall(canvas, ballCenter, ballRadius);
    } else {
      _paintBall(canvas, Offset(s / 2, s / 2), s * 0.46);
    }
  }

  /// خطوط سرعة صفراء متوازية تتجه نحو الكرة
  void _paintTrail(Canvas canvas, double s, Offset ball, double r) {
    final dir = Offset(math.cos(math.pi * 0.78), math.sin(math.pi * 0.78));

    void line(Offset from, double length, double width, double alpha) {
      final paint = Paint()
        ..color = AppColors.accent.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from, from + dir * length, paint);
    }

    // ثلاث خطوط بأطوال متدرجة — أقربها للكرة أطول وأوضح
    final base = ball + dir * (r * 1.25);
    final side = Offset(-dir.dy, dir.dx);
    line(base + side * (r * 0.10), s * 0.30, s * 0.075, 1);
    line(base + side * (r * 0.62) - dir * (s * 0.02), s * 0.21, s * 0.06, 0.85);
    line(base - side * (r * 0.42) - dir * (s * 0.04), s * 0.15, s * 0.05, 0.7);
  }

  /// كرة قدم كلاسيكية: خماسي بالمنتصف + 5 رقع على الأطراف + خطوط الدرز
  void _paintBall(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    // جسم الكرة — أبيض مع تظليل خفيف يعطي إحساس الكروية
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 1.2,
          colors: [Colors.white, const Color(0xFFDDE1E6)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final ink = Paint()..color = AppColors.inkFixed;
    final seam = Paint()
      ..color = AppColors.inkFixed
      ..strokeWidth = r * 0.07
      ..strokeCap = StrokeCap.round;

    // الخماسي المركزي — رأسه للأعلى
    canvas.drawPath(_pentagon(c, r * 0.36, -math.pi / 2), ink);

    for (var k = 0; k < 5; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / 5;
      final dir = Offset(math.cos(a), math.sin(a));
      // رقعة على حافة الكرة، حرفها الداخلي باتجاه المركز
      canvas.drawPath(_pentagon(c + dir * (r * 1.04), r * 0.42, a + math.pi), ink);
      // خط الدرز من رأس الخماسي المركزي إلى الرقعة
      canvas.drawLine(c + dir * (r * 0.36), c + dir * (r * 0.64), seam);
    }

    // ظل داخلي خفيف أسفل الكرة
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.4, 0.45),
          radius: 1.1,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.10)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.restore();

    // حد خارجي رفيع يفصل الكرة عن أي خلفية فاتحة
    canvas.drawCircle(
      c,
      r - r * 0.015,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = AppColors.inkFixed.withValues(alpha: 0.08),
    );
  }

  Path _pentagon(Offset c, double r, double rot) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = rot + i * 2 * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _ShootMarkPainter oldDelegate) =>
      oldDelegate.showTrail != showTrail;
}

/// أيقونة التطبيق الكاملة (1024×1024) — تُصدَّر PNG عبر اختبار golden
/// ثم تتحول لأيقونات أندرويد/iOS/ويب بواسطة flutter_launcher_icons.
class ShootAppIcon extends StatelessWidget {
  const ShootAppIcon({
    super.key,
    this.transparentBackground = false,
    this.contentScale = 1,
  });

  /// true = طبقة أمامية للأيقونة التكيفية بأندرويد (خلفية شفافة)
  final bool transparentBackground;

  /// تصغير المحتوى داخل المنطقة الآمنة للأيقونة التكيفية (~0.6)
  final double contentScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: transparentBackground ? null : AppColors.brandGradient,
        ),
        child: Stack(
          children: [
            if (!transparentBackground)
              const Positioned.fill(child: CustomPaint(painter: _IconRingsPainter())),
            Center(
              child: FractionallySizedBox(
                widthFactor: contentScale,
                heightFactor: contentScale,
                child: const CustomPaint(
                  painter: _ShootMarkPainter(showTrail: true),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// دوائر خطوط الملعب الخافتة بخلفية الأيقونة — نفس لمسة السبلاش
class _IconRingsPainter extends CustomPainter {
  const _IconRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(-size.width * 0.05, -size.height * 0.05),
      size.width * 0.34,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 1.05),
      size.width * 0.42,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
