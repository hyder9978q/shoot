import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/field.dart';
import '../theme/app_colors.dart';
import 'field_visual.dart';
import 'shimmer.dart';

/// صورة ملعب واحدة — صورة حقيقية (صورة المالك أو صورة Google Places) إذا متوفرة،
/// وإلا (أو عند فشل التحميل) رسمة الملعب المرسومة حسب الرياضة.
///
/// أثناء التحميل تظهر لمعة (shimmer) بدل الشاشة الفارغة، ثم تتحول الصورة بنعومة.
class FieldImage extends StatelessWidget {
  const FieldImage({super.key, required this.field, this.borderRadius});

  final Field field;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return FieldPhoto(
      sport: field.sport,
      url: field.displayImageUrl,
      borderRadius: borderRadius,
    );
  }
}

/// صورة ملعب من رابط محدد — الوحدة الأساسية للبطاقات والمعرض.
///
/// - رابط فارغ → الرسمة المرسومة مباشرة.
/// - أثناء التحميل → لمعة (shimmer) فوق الرسمة.
/// - فشل التحميل → نبقى على الرسمة بدون أي كسر.
class FieldPhoto extends StatelessWidget {
  const FieldPhoto({
    super.key,
    required this.sport,
    required this.url,
    this.borderRadius,
  });

  final Sport sport;
  final String url;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final visual = FieldVisual(sport: sport, borderRadius: borderRadius);
    if (url.isEmpty) return visual;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الرسمة تبقى خلفية دائمة — لو فشلت الصورة تبقى ظاهرة
          visual,
          // الصورة تتنزل مرة وحدة وتتخزن بالجهاز — أي ظهور بعدها فوري
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            // دخول ناعم بدل الظهور المفاجئ
            fadeInDuration: const Duration(milliseconds: 300),
            fadeInCurve: Curves.easeOutCubic,
            // من الذاكرة المحلية: بدون أي وميض
            fadeOutDuration: Duration.zero,
            // أثناء التحميل: لمعة ناعمة بدل الفراغ
            placeholder: (_, _) => Shimmer(borderRadius: borderRadius),
            // فشل التحميل: نبقى على الرسمة بدون أي كسر
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// معرض صور الملعب — يمرّر (swipe) بين عدة صور مع نقاط سفلية.
///
/// إذا ما بيه صور حقيقية يعرض الرسمة المرسومة كصفحة وحيدة بدون نقاط.
class FieldGallery extends StatefulWidget {
  const FieldGallery({super.key, required this.field});

  final Field field;

  @override
  State<FieldGallery> createState() => _FieldGalleryState();
}

class _FieldGalleryState extends State<FieldGallery> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.field.galleryImages;

    // ما بيه صور: صفحة وحيدة بالرسمة المرسومة
    if (images.length <= 1) {
      return FieldPhoto(
        sport: widget.field.sport,
        url: images.isEmpty ? '' : images.first,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) =>
              FieldPhoto(sport: widget.field.sport, url: images[i]),
        ),
        // نقاط تدل على عدد الصور والصورة الحالية
        PositionedDirectional(
          bottom: 12,
          start: 0,
          end: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
