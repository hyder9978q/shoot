import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// نجوم للعرض فقط (1–5)
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= rating
                ? AppColors.star
                : AppColors.border,
          ),
      ],
    );
  }
}

/// نجوم قابلة للاختيار — لنموذج التقييم
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 40,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            key: Key('star-$i'),
            onPressed: () => onChanged(i),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            icon: Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= rating
                  ? AppColors.star
                  : AppColors.grey.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}
