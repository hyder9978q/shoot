import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// مؤشر تحميل ناعم — لمعة تمرّ فوق مساحة رمادية فاتحة أثناء انتظار المحتوى.
///
/// بديل عن الشاشة الفارغة: يعطي إحساس إن شي راح يوصل. يحترم إعداد
/// "تقليل الحركة" بالنظام فيتحول لمساحة ثابتة بدون وميض.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.borderRadius});

  final BorderRadius? borderRadius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final base = AppColors.subtleFill;
    final highlight = AppColors.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.55);

    // تقليل الحركة: مساحة ثابتة بدون وميض
    if (reduceMotion) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: base,
          borderRadius: widget.borderRadius,
        ),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // اللمعة تمرّ من اليسار لليمين بشكل متكرر
          final t = _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 - 2 * (1 - t), 0),
                end: Alignment(1 - 2 * (1 - t), 0),
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
