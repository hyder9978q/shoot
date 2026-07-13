import 'package:flutter/material.dart';

/// يخلي أي عنصر "يحس" بالضغطة — ينكمش 3% وقت اللمس ويرجع فوراً.
///
/// مبدأ من فلسفة Emil Kowalski للحركات: الواجهة لازم تثبت للمستخدم
/// إنها سمعته. الانكماش خفيف (0.97) وسريع (120ms) مع ease-out قوي.
///
/// يستخدم [Listener] حتى ما يتنافس مع InkWell الداخلي على الضغطة —
/// مرر [onTap] فقط إذا العنصر ما بيه InkWell خاص بيه.
/// يحترم إعداد "تقليل الحركة" بالنظام.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget child = AnimatedScale(
      scale: _pressed && !reduceMotion ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );

    if (widget.onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: child,
      );
    }

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: child,
    );
  }
}
