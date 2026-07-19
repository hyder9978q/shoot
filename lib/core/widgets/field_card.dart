import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/fields/screens/field_details_screen.dart';
import '../constants/app_strings.dart';
import '../models/field.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/arabic_num.dart';
import 'field_image.dart';
import 'pressable.dart';

/// بطاقة ملعب — صورة + الاسم والتقييم والموقع والسعر وقلب المفضلة.
/// مشتركة بين الرئيسية وشاشة المفضلة.
class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.field});

  final Field field;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FieldDetailsScreen(field: field),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصورة مع شارة الرياضة وقلب المفضلة
                SizedBox(
                  height: 128,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FieldImage(field: field),
                      // تدرّج غامق خفيف أسفل الصورة — يخلي الشارات والحافة
                      // واضحين فوق أي صورة مهما كانت فاتحة
                      const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [Color(0x40000000), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: 10,
                        start: 10,
                        child: _SportPill(sport: field.sport),
                      ),
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: FavoriteButton(fieldId: field.id),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              field.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          RatingBadge(rating: field.rating),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.location,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          PriceText(price: field.pricePerHour),
                          const Spacer(),
                          Text(
                            '${ArabicNum.count(field.reviewsCount)} ${AppStrings.reviewWord}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شارة نوع الملعب فوق الصورة
class _SportPill extends StatelessWidget {
  const _SportPill({required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sport.icon, size: 14, color: const Color(0xFF16A34A)),
          const SizedBox(width: 4),
          Text(
            sport.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

/// السعر بصيغة التصميم: رقم أخضر ثقيل + "د.ع/س" خافت
class PriceText extends StatelessWidget {
  const PriceText({super.key, required this.price, this.size = 15});

  final int price;
  final double size;

  @override
  Widget build(BuildContext context) {
    // أماكن مسحوبة من الخرائط بعدها ما مسجلة عدنا — ما عدها سعر، ننصح بالاتصال
    if (price <= 0) {
      return Text(
        AppStrings.priceOnCall,
        style: TextStyle(
          fontSize: size * 0.85,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          ArabicNum.money(price),
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          AppStrings.perHourShort,
          style: TextStyle(
            fontSize: size * 0.7,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

/// نجمة صفراء + الرقم — شارة التقييم الموحّدة
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.rating, this.size = 12});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size + 4, color: AppColors.star),
        const SizedBox(width: 2),
        Text(
          '$rating',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
      ],
    );
  }
}

/// زر قلب المفضلة — يتبدل فوراً ويحفظ بالخلفية
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.fieldId, this.size = 36});

  final String fieldId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: UserService.instance.revision,
      builder: (context, _, _) {
        final isFav = UserService.instance.isFavorite(fieldId);
        return Pressable(
          onTap: () => UserService.instance.toggleFavorite(fieldId),
          child: Container(
            key: Key('fav-$fieldId'),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(size * 0.32),
            ),
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: size * 0.52,
              color: isFav
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF6B7280),
            ),
          ),
        );
      },
    );
  }
}
