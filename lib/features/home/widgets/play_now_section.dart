import 'package:flutter/material.dart';


import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/field_card.dart' show PriceText, RatingBadge;
import '../../../core/widgets/pressable.dart';
import '../../fields/screens/field_details_screen.dart';

/// ملعب + أقرب ساعة فاضية بيه اليوم
class _PlayNowEntry {
  const _PlayNowEntry(this.field, this.freeHour);

  final Field field;
  final int freeHour;
}

/// قسم "العب اليوم ⚡" — الملاعب اللي بيها وقت فاضي اليوم، الأقرب أولاً.
/// يختفي أثناء البحث والفلترة حتى ما يزاحم النتائج.
class PlayNowSection extends StatefulWidget {
  const PlayNowSection({super.key});

  /// للاختبارات واللقطات: تثبيت "الساعة الحالية" حتى تكون النتائج حتمية
  @visibleForTesting
  static int? debugNowHour;

  @override
  State<PlayNowSection> createState() => _PlayNowSectionState();
}

class _PlayNowSectionState extends State<PlayNowSection> {
  List<_PlayNowEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
    // أي حجز جديد يغيّر التوفر → نحدث القسم
    BookingsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    BookingsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final fields = await FieldsService.instance.loadFields();
    final booked = await BookingsService.instance.todayBookedHours(fields);
    final nowHour = PlayNowSection.debugNowHour ?? DateTime.now().hour;

    final entries = <_PlayNowEntry>[];
    for (final field in fields) {
      final taken = booked[field.id] ?? const <int>{};
      // أقرب ساعة فاضية من هسه لنهاية الدوام
      for (var h = nowHour < field.openHour ? field.openHour : nowHour;
          h < field.closeHour;
          h++) {
        if (!taken.contains(h)) {
          entries.add(_PlayNowEntry(field, h));
          break;
        }
      }
    }
    // الأقرب وقتاً أولاً، وعند التساوي الأعلى تقييماً
    entries.sort((a, b) {
      final byHour = a.freeHour.compareTo(b.freeHour);
      return byHour != 0
          ? byHour
          : b.field.rating.compareTo(a.field.rating);
    });

    if (mounted) setState(() => _entries = entries.take(6).toList());
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (entries == null || entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
          child: Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 20,
                color: AppColors.accent,
              ),
              const SizedBox(width: 4),
              Text(
                AppStrings.playTodayTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              const Spacer(),
              Text(
                AppStrings.playTodaySubtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          // صورة 100 + بلوك النص بخط Cairo
          height: 194,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, i) => _PlayNowCard(entry: entries[i]),
          ),
        ),
      ],
    );
  }
}

class _PlayNowCard extends StatelessWidget {
  const _PlayNowCard({required this.entry});

  final _PlayNowEntry entry;

  @override
  Widget build(BuildContext context) {
    final field = entry.field;
    final hourLabel = '${entry.freeHour.toString().padLeft(2, '0')}:00';

    return Pressable(
      child: SizedBox(
        width: 212,
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FieldDetailsScreen(field: field),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FieldImage(field: field),
                        // شارة الوقت الفاضي
                        PositionedDirectional(
                          top: 10,
                          end: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFACC15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '${AppStrings.freeAtLabel} ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  hourLabel,
                                  textDirection: TextDirection.ltr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                field.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: AppColors.dark,
                                ),
                              ),
                            ),
                            RatingBadge(rating: field.rating),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          field.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        PriceText(price: field.pricePerHour),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
