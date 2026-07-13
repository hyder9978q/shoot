import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// أرضية الملعب الليلية — مدرجات غامقة + عشب أخضر بمنظور
class StadiumPainter extends CustomPainter {
  const StadiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // السماء والمدرجات — غامق بهوية شوت
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.34),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0F1A), AppColors.inkFixed],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.34)),
    );

    // أضواء الجمهور — نقاط خافتة متفرقة (ثابتة، مو عشوائية)
    final crowd = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final rng = math.Random(7);
    for (var i = 0; i < 160; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.30),
        rng.nextDouble() * 1.6 + 0.5,
        crowd,
      );
    }

    // العشب — تدرج الهوية مع أشرطة قص أفقية (منظور)
    final grassRect = Rect.fromLTWH(0, h * 0.34, w, h * 0.66);
    canvas.drawRect(
      grassRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryDeep, AppColors.primary],
        ).createShader(grassRect),
    );

    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.05);
    var y = h * 0.34;
    var bandH = h * 0.035;
    var dark = false;
    while (y < h) {
      if (dark) canvas.drawRect(Rect.fromLTWH(0, y, w, bandH), stripe);
      y += bandH;
      bandH *= 1.28; // الأشرطة تكبر كل ما تقربنا — إحساس المنظور
      dark = !dark;
    }

    // خط منطقة الجزاء + نقطة الجزاء
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.45);
    final boxTop = h * 0.40;
    final path = Path()
      ..moveTo(w * 0.02, h * 0.62)
      ..lineTo(w * 0.14, boxTop)
      ..lineTo(w * 0.86, boxTop)
      ..lineTo(w * 0.98, h * 0.62);
    canvas.drawPath(path, line);
    canvas.drawCircle(
      Offset(w / 2, h * 0.80),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// المرمى — قائمان وعارضة بيض + شبكة خفيفة
class GoalPainter extends CustomPainter {
  const GoalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // الشبكة
    final net = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.22);
    const cells = 12;
    for (var i = 0; i <= cells; i++) {
      final x = w * i / cells;
      canvas.drawLine(Offset(x, 0), Offset(x, h), net);
    }
    for (var i = 0; i <= 6; i++) {
      final y = h * i / 6;
      canvas.drawLine(Offset(0, y), Offset(w, y), net);
    }

    // ظل خفيف داخل المرمى يعطي عمق
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // الإطار: عارضة + قائمان
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(5, w * 0.018)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawLine(Offset(0, 0), Offset(w, 0), frame);
    canvas.drawLine(Offset(0, 0), Offset(0, h), frame);
    canvas.drawLine(Offset(w, 0), Offset(w, h), frame);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// الحارس — شخصية بسيطة بقفازات صفراء (هوية شوت)
class KeeperPainter extends CustomPainter {
  const KeeperPainter({this.armsUp = false});

  /// الإيدين مرفوعة (وضعية النطة)
  final bool armsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final jersey = Paint()..color = AppColors.accent;
    final skin = Paint()..color = const Color(0xFFE0AC69);
    final dark = Paint()..color = AppColors.inkFixed;
    final glove = Paint()..color = AppColors.accent;

    // الرجلين
    final legs = Paint()
      ..color = AppColors.inkFixed
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - w * 0.10, h * 0.62),
      Offset(cx - w * 0.16, h * 0.92),
      legs,
    );
    canvas.drawLine(
      Offset(cx + w * 0.10, h * 0.62),
      Offset(cx + w * 0.16, h * 0.92),
      legs,
    );

    // الجذع — قميص أصفر
    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.47),
        width: w * 0.42,
        height: h * 0.36,
      ),
      Radius.circular(w * 0.12),
    );
    canvas.drawRRect(torso, jersey);

    // الإيدين + القفازات
    final arms = Paint()
      ..color = AppColors.accent
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    final armY = armsUp ? h * 0.18 : h * 0.52;
    canvas.drawLine(
      Offset(cx - w * 0.18, h * 0.36),
      Offset(cx - w * 0.42, armY),
      arms,
    );
    canvas.drawLine(
      Offset(cx + w * 0.18, h * 0.36),
      Offset(cx + w * 0.42, armY),
      arms,
    );
    canvas.drawCircle(Offset(cx - w * 0.42, armY), w * 0.09, glove);
    canvas.drawCircle(Offset(cx + w * 0.42, armY), w * 0.09, glove);

    // الراس
    canvas.drawCircle(Offset(cx, h * 0.16), w * 0.14, skin);
    // شعر
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, h * 0.16), radius: w * 0.14),
      math.pi,
      math.pi,
      false,
      dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06,
    );
  }

  @override
  bool shouldRepaint(covariant KeeperPainter oldDelegate) =>
      oldDelegate.armsUp != armsUp;
}
