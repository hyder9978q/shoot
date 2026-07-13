import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/booking.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/widgets/field_visual.dart';
import '../../../core/widgets/pressable.dart';
import '../../fields/screens/field_details_screen.dart';

/// تبويب حجوزاتي — قائمة الحجوزات الحقيقية من Firestore
class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  List<Booking>? _bookings;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
    // أي حجز جديد أو إلغاء بأي مكان بالتطبيق → القائمة تتحدث لحالها
    BookingsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    BookingsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bookings = await BookingsService.instance.myBookings();
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bookings = [];
          _error = true;
        });
      }
    }
  }

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.cancelBookingTitle),
        content: Text(
          AppStrings.cancelBookingConfirm,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.dark.withValues(alpha: 0.8),
            height: 1.7,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.keepBooking),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.yesCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await BookingsService.instance.cancelBooking(booking);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingCancelled)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingError)),
      );
    }
  }

  /// التبويب المختار: 0 = القادمة، 1 = السابقة
  int _tab = 0;

  /// الحجز قادم إذا وقته ما فات
  bool _isUpcoming(Booking booking) {
    final day = DateTime.tryParse(booking.date);
    if (day == null) return true;
    final end = DateTime(day.year, day.month, day.day, booking.hour + 1);
    return end.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final all = _bookings;
    final List<Booking>? shown = all == null
        ? null
        : [
            for (final b in all)
              if (_isUpcoming(b) == (_tab == 0)) b,
          ];

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس أبيض: العنوان + تبويبات القادمة/السابقة
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.myBookingsTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.subtleFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _SegTab(
                          label: AppStrings.upcomingTab,
                          selected: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                        _SegTab(
                          label: AppStrings.pastTab,
                          selected: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: shown == null
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                        itemCount: 3,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (_, _) => const _BookingSkeleton(),
                      )
                    : shown.isEmpty
                        ? _EmptyState(error: _error, past: _tab == 1)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, i) => _BookingCard(
                              booking: shown[i],
                              past: _tab == 1,
                              onCancel: () => _cancel(shown[i]),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// تبويب مقسّم (القادمة/السابقة)
class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected ? AppColors.cardShadow : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? AppColors.dark : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة حجز — شريط لوني علوي + صورة + حالة + أزرار
class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.past,
    required this.onCancel,
  });

  final Booking booking;
  final bool past;
  final VoidCallback onCancel;

  void _openField(BuildContext context) {
    final field = FieldsService.instance.byId(booking.fieldId);
    if (field == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.fieldNotFound)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FieldDetailsScreen(field: field)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // شريط الحالة: أخضر = مؤكد، رمادي = منتهي
          Container(
            height: 6,
            color: past ? AppColors.border : AppColors.primary,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة الملعب (رسمة الملعب حسب الرياضة)
                SizedBox(
                  width: 70,
                  height: 70,
                  child: FieldVisual(
                    sport: booking.sport,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              booking.fieldName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: past
                                  ? AppColors.subtleFill
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              past
                                  ? AppStrings.doneLabel
                                  : AppStrings.confirmedLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: past
                                    ? AppColors.grey
                                    : AppColors.primaryDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${DateLabels.label(booking.date)} · '
                        '${booking.hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        booking.location,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // أزرار البطاقة
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: () => _openField(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: past
                          ? null
                          : BoxDecoration(
                              border: BorderDirectional(
                                end: BorderSide(color: AppColors.hairline),
                              ),
                            ),
                      child: Text(
                        AppStrings.detailsAction,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!past)
                  Expanded(
                    child: Pressable(
                      onTap: onCancel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Text(
                          AppStrings.cancelBookingTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.grey,
                          ),
                        ),
                      ),
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

/// حالة فارغة — تعلّم المستخدم شنو راح يشوف هنا
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.error, this.past = false});

  final bool error;

  /// تبويب "السابقة" — رسالة مختلفة
  final bool past;

  @override
  Widget build(BuildContext context) {
    // ListView حتى يشتغل السحب-للتحديث حتى وهي فارغة
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.event_available_outlined,
              size: 48,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          error
              ? AppStrings.bookingsLoadError
              : past
                  ? AppStrings.noPastBookings
                  : AppStrings.noBookingsTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (!error && !past) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.noBookingsMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.grey,
                  fontWeight: FontWeight.w600,
                  height: 1.7,
                ),
          ),
        ],
      ],
    );
  }
}

/// هيكل تحميل بطاقة حجز
class _BookingSkeleton extends StatelessWidget {
  const _BookingSkeleton();

  @override
  Widget build(BuildContext context) {
    final shimmer = AppColors.subtleFill;

    Widget block(double width, double height, [double radius = 8]) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmer,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              block(46, 46, 14),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(130, 15),
                  const SizedBox(height: 6),
                  block(90, 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          block(double.infinity, 13),
        ],
      ),
    );
  }
}
