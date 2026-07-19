import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/models/review.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/services/reviews_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/widgets/field_card.dart' show FavoriteButton;
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/rating_stars.dart';
import '../../bookings/screens/booking_checkout_screen.dart';

/// تفاصيل الملعب + اختيار الوقت + تأكيد الحجز بالعربون
class FieldDetailsScreen extends StatefulWidget {
  const FieldDetailsScreen({super.key, required this.field});

  final Field field;

  @override
  State<FieldDetailsScreen> createState() => _FieldDetailsScreenState();
}

class _FieldDetailsScreenState extends State<FieldDetailsScreen> {
  TimeSlot? _selectedSlot;

  /// اليوم المختار للحجز (yyyy-MM-dd) — افتراضياً اليوم
  String _date = BookingsService.todayDate();

  /// null = بعدها تحمّل من قاعدة البيانات
  List<TimeSlot>? _slots;

  /// تقييمات الملعب — null = بعدها تتحمل
  List<Review>? _reviews;

  @override
  void initState() {
    super.initState();
    _loadSlots();
    _loadReviews();
    ReviewsService.instance.revision.addListener(_loadReviews);
  }

  @override
  void dispose() {
    ReviewsService.instance.revision.removeListener(_loadReviews);
    super.dispose();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews =
          await ReviewsService.instance.fieldReviews(widget.field.id);
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {
      if (mounted) setState(() => _reviews = const []);
    }
  }

  Future<void> _openRateDialog() async {
    final myReview = ReviewsService.instance.myReviewIn(_reviews ?? const []);
    var rating = myReview?.rating ?? 5;
    final commentController =
        TextEditingController(text: myReview?.comment ?? '');

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(AppStrings.rateField),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingInput(
                rating: rating,
                onChanged: (v) => setDialogState(() => rating = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                maxLength: 200,
                inputFormatters: [InputSanitizer.deny()],
                decoration: const InputDecoration(
                  hintText: AppStrings.reviewCommentHint,
                  counterText: '',
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.submitReview),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;
    try {
      await ReviewsService.instance.submitReview(
        widget.field,
        rating: rating,
        comment: commentController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.reviewSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.reviewError)),
      );
    }
  }

  Future<void> _loadSlots() async {
    final date = _date;
    final slots = await BookingsService.instance.slotsFor(widget.field, date);
    // نتجاهل النتيجة إذا المستخدم غيّر اليوم أثناء التحميل
    if (mounted && _date == date) setState(() => _slots = slots);
  }

  void _pickDate(String date) {
    if (date == _date) return;
    setState(() {
      _date = date;
      _slots = null;
      _selectedSlot = null;
    });
    _loadSlots();
  }

  /// اختيار الوقت مكتمل → نروح لشاشة تأكيد الحجز والدفع (٠٧ بالتصميم)
  Future<void> _confirmBooking() async {
    final slot = _selectedSlot;
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.pickTimeFirst)),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingCheckoutScreen(
          field: widget.field,
          slot: slot,
          date: _date,
        ),
      ),
    );

    // بعد الرجوع من الدفع: نحدّث الأوقات (ممكن انحجز الوقت)
    if (!mounted) return;
    setState(() {
      _selectedSlot = null;
      _slots = null;
    });
    _loadSlots();
  }


  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final slots = _slots;
    final myReview = ReviewsService.instance.myReviewIn(_reviews ?? const []);

    return Scaffold(
      backgroundColor: AppColors.surface,
      // شريط الحجز الثابت
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkFixed.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.startsFrom,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          ArabicNum.money(field.pricePerHour),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          AppStrings.perHourShort,
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
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _confirmBooking,
                      child: const Text(AppStrings.bookNow),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // صورة الملعب — رأس بطول 280 مع زرين دائريين
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            automaticallyImplyLeading: false,
            titleSpacing: 20,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundGlassButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                FavoriteButton(fieldId: field.id, size: 44),
              ],
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // معرض صور قابل للتمرير (swipe) + نقاط
                  FieldGallery(field: field),
                  // تدرّج علوي حتى يبقى الزرين واضحين — لا يمنع التمرير
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x59111827), Colors.transparent],
                          stops: [0, 0.4],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الاسم + صندوق التقييم
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.name,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                color: AppColors.dark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    field.location,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                                if (field.hasLocation) ...[
                                  const SizedBox(width: 10),
                                  Pressable(
                                    onTap: () => launchUrl(
                                      Uri.parse(
                                        'https://www.google.com/maps/search/?api=1&query=${field.lat},${field.lng}',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.directions_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          AppStrings.directionsLabel,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // صندوق التقييم الأخضر
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryLight),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 17,
                                  color: AppColors.star,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${field.rating}',
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.dark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ArabicNum.count(field.reviewsCount)} ${AppStrings.reviewWord}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ثلاث خانات: الأرضية، الحجم، الإنارة
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _FeatureBox(
                        value: field.surfaceLabel,
                        label: AppStrings.surfaceLabel,
                      ),
                      const SizedBox(width: 9),
                      _FeatureBox(
                        value: field.sizeText,
                        label: AppStrings.sizeLabel,
                      ),
                      const SizedBox(width: 9),
                      _FeatureBox(
                        value: AppStrings.lightingValue,
                        label: field.lightingLabel,
                      ),
                    ],
                  ),
                  // عن الملعب
                  if (field.description.isNotEmpty) ...[
                    const _SectionTitle(AppStrings.aboutFieldTitle),
                    Text(
                      field.description,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                        height: 1.8,
                      ),
                    ),
                  ],
                  // المرافق — شارات بنقطة خضراء
                  if (field.amenities.isNotEmpty) ...[
                    const _SectionTitle(AppStrings.amenitiesTitle),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final amenity in field.amenities)
                          _AmenityPill(label: amenity.label),
                      ],
                    ),
                  ],
                  // اليوم والوقت
                  const _SectionTitle(AppStrings.todaySlotsTitle),
                  SizedBox(
                    height: 62,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 7,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final date = DateLabels.dateFor(i);
                        return _DayChip(
                          date: date,
                          selected: _date == date,
                          onTap: () => _pickDate(date),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (slots == null)
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (var i = 0; i < 8; i++)
                          Container(
                            width: 86,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.subtleFill,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final slot in slots)
                          _SlotChip(
                            slot: slot,
                            selected: _selectedSlot == slot,
                            onTap: slot.isBooked
                                ? null
                                : () => setState(() => _selectedSlot = slot),
                          ),
                      ],
                    ),
                  // التقييمات
                  Row(
                    children: [
                      _SectionTitle(
                        _reviews == null
                            ? AppStrings.reviewsTitle
                            : '${AppStrings.reviewsTitle} (${ArabicNum.count(_reviews!.length)})',
                      ),
                      const Spacer(),
                      Pressable(
                        onTap: _openRateDialog,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 22, bottom: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 17,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                myReview == null
                                    ? AppStrings.rateField
                                    : AppStrings.editMyReview,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_reviews == null)
                    for (var i = 0; i < 2; i++)
                      Container(
                        height: 84,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.subtleFill,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      )
                  else if (_reviews!.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryLight),
                      ),
                      child: Text(
                        AppStrings.noReviewsYet,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primaryDark,
                          height: 1.7,
                        ),
                      ),
                    )
                  else
                    for (final review in _reviews!)
                      _ReviewCard(review: review),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// عنوان قسم — 16px ثقيل بمسافات التصميم
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.dark,
        ),
      ),
    );
  }
}

/// خانة ميزة — القيمة فوق والتسمية تحت على خلفية رمادية فاتحة
class _FeatureBox extends StatelessWidget {
  const _FeatureBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة مرفق — نقطة خضراء + الاسم داخل كبسولة بحد
class _AmenityPill extends StatelessWidget {
  const _AmenityPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// زر دائري زجاجي فوق الصورة (رجوع)
class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 19,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

/// شيب اختيار اليوم
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateLabels.shortLabel(date),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? AppColors.white : AppColors.dark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ArabicNum.convert(DateLabels.dayMonth(date)),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: selected
                    ? AppColors.white.withValues(alpha: 0.85)
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شيب وقت — محجوز (مشطوب)، مختار (أخضر)، متاح (أبيض بحد)
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final TimeSlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = slot.isBooked;
    final hour = '${slot.hour.toString().padLeft(2, '0')}:00';

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.subtleFill
              : selected
                  ? AppColors.primary
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? AppColors.subtleFill
                : selected
                    ? AppColors.primary
                    : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          hour,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontWeight: disabled ? FontWeight.w700 : FontWeight.w800,
            fontSize: 13,
            color: disabled
                ? AppColors.muted
                : selected
                    ? AppColors.white
                    : AppColors.dark,
            decoration: disabled ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.muted,
            decorationThickness: 2,
          ),
        ),
      ),
    );
  }
}

/// بطاقة تقييم — أفاتار بحرف الاسم + النجوم + التعليق
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.userName.isEmpty
                        ? '؟'
                        : review.userName.characters.first,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RatingStars(rating: review.rating, size: 13),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppColors.grey,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
