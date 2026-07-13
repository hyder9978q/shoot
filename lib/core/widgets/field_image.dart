import 'package:flutter/material.dart';

import '../models/field.dart';
import 'field_visual.dart';

/// صورة الملعب — صورة حقيقية من الشبكة إذا متوفرة،
/// وإلا (أو عند فشل التحميل) رسمة الملعب المرسومة حسب الرياضة.
/// أثناء التحميل تظهر الرسمة كخلفية فتتحول الصورة فوقها بنعومة.
class FieldImage extends StatelessWidget {
  const FieldImage({super.key, required this.field, this.borderRadius});

  final Field field;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final visual = FieldVisual(sport: field.sport, borderRadius: borderRadius);
    if (field.imageUrl.isEmpty) return visual;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          visual,
          Image.network(
            field.imageUrl,
            fit: BoxFit.cover,
            // دخول ناعم بدل الظهور المفاجئ
            frameBuilder: (context, child, frame, wasSyncLoaded) {
              if (wasSyncLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: child,
              );
            },
            // فشل التحميل: نبقى على الرسمة بدون أي كسر
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
