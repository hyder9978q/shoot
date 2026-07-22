import 'package:flutter/material.dart';

import '../../../core/constants/app_features.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/cancellation.dart';
import '../../../core/models/field.dart';
import '../../../core/navigation/app_tabs.dart';
import '../../../core/services/cancellations_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/pressable.dart';
import 'booking_checkout_screen.dart';

/// بدائل فورية بعد ما يلغي صاحب الملعب حجز اللاعب.
///
/// نفس اليوم ونفس الساعة ونفس المدينة والرياضة — والأقرب أول.
/// الحجز من هنا "مضمون": بدون عربون (إذا الميزة مفعّلة).
class ReplacementScreen extends StatefulWidget {
  const ReplacementScreen({super.key, required this.cancellation});

  final Cancellation cancellation;

  @override
  State<ReplacementScreen> createState() => _ReplacementScreenState();
}

class _ReplacementScreenState extends State<ReplacementScreen> {
  List<Alternative>? _alternatives;

  @override
  void initState() {
    super.initState();
    // فتح الشاشة = اللاعب شاف الإشعار
    CancellationsService.instance.markSeen(widget.cancellation);
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await CancellationsService.instance.findAlternatives(
        widget.cancellation,
      );
      if (mounted) setState(() => _alternatives = list);
    } catch (_) {
      if (mounted) setState(() => _alternatives = const []);
    }
  }

  Future<void> _book(Field field) async {
    final cancellation = widget.cancellation;
    final waived = AppFeatures.guaranteeWaivesDeposit;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingCheckoutScreen(
          field: field,
          slot: TimeSlot(hour: cancellation.hour, isBooked: false),
          date: cancellation.date,
          replacesCancellationId: cancellation.id,
          depositWaived: waived,
        ),
      ),
    );
    // رجع من الحجز — نحدّث البدائل (الوكت ممكن انحجز)
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cancellation = widget.cancellation;
    final list = _alternatives;
    final time = TimeLabels.hour12(cancellation.hour);
    final dayLabel = DateLabels.label(cancellation.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(dayLabel: dayLabel, time: time, cancellation: cancellation),
            Expanded(
              child: list == null
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                      itemCount: 3,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, _) => const _AlternativeSkeleton(),
                    )
                  : list.isEmpty
                  ? const _EmptyAlternatives()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _AlternativeCard(
                        alternative: list[i],
                        onBook: () => _book(list[i].field),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// رأس الشاشة — اعتذار + تفاصيل الحجز الملغي
class _Header extends StatelessWidget {
  const _Header({
    required this.dayLabel,
    required this.time,
    required this.cancellation,
  });

  final String dayLabel;
  final String time;
  final Cancellation cancellation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pressable(
                onTap: () => Navigator.of(context).pop(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.dark,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  AppStrings.replacementTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.replacementSubtitle(dayLabel, time),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          // شارة الضمان — أهم رسالة بالشاشة
          if (AppFeatures.guaranteeWaivesDeposit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.guaranteedExplain,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDeep,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // سبب الإلغاء إذا ذكره صاحب الملعب
          if (cancellation.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.cancelReasonLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cancellation.reason,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// بطاقة بديل — صورة + اسم + بُعد + سعر + زر الحجز
class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({required this.alternative, required this.onBook});

  final Alternative alternative;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final field = alternative.field;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 6, color: AppColors.primary),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: FieldImage(
                    field: field,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${field.area}، ${field.city}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (alternative.hasDistance) ...[
                            Icon(
                              Icons.near_me_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${AppStrings.awayLabel} '
                              '${Geo.label(alternative.distanceKm)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: AppColors.star,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            field.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.grey,
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
          // السعر + زر الحجز
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ArabicNum.money(field.pricePerHour)} '
                        '${AppStrings.iqd}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                        ),
                      ),
                      if (AppFeatures.guaranteeWaivesDeposit)
                        Text(
                          AppStrings.guaranteedNoDeposit,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                Pressable(
                  child: ElevatedButton(
                    onPressed: onBook,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text(AppStrings.bookReplacement),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ما بيه بدائل — نوجّهه لتصفّح الملاعب بدل ما نتركه بطريق مسدود
class _EmptyAlternatives extends StatelessWidget {
  const _EmptyAlternatives();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          AppStrings.replacementEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.grey,
            height: 1.8,
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Pressable(
            child: ElevatedButton.icon(
              onPressed: () {
                AppTabs.go(AppTabs.home);
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 26),
              ),
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text(AppStrings.replacementBrowse),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlternativeSkeleton extends StatelessWidget {
  const _AlternativeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double w, double h, [double r = 8]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          block(74, 74, 14),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              block(140, 16),
              const SizedBox(height: 8),
              block(100, 12),
              const SizedBox(height: 12),
              block(80, 12),
            ],
          ),
        ],
      ),
    );
  }
}
