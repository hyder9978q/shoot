import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/field.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/services/cancellations_service.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/pressable.dart';
import 'field_manage_screen.dart';

/// لوحة صاحب الملعب — أرباح اليوم والأسبوع + أوقات اليوم (شاشة ١١ بالتصميم)
class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key, required this.fields});

  /// ملاعب هذا المالك (محمّلة مسبقاً من تبويب حسابي)
  final List<Field> fields;

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  /// نسخة قابلة للتحديث من ملاعب المالك — تتغير لما يرفع/يحذف صور
  late final List<Field> _fields = List.of(widget.fields);

  /// أوقات اليوم لكل ملعب — null = بعدها تتحمل
  Map<String, List<TimeSlot>>? _slotsByField;

  /// حجوزات اليوم لكل ملعب — منها نعرف منو اللاعب بكل وقت محجوز
  Map<String, List<Booking>> _bookingsByField = const {};

  /// عدد الحجوزات لكل يوم من آخر ٧ أيام (لمخطط الأرباح)
  List<int> _weekBookings = const [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _load();
    BookingsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    BookingsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final today = BookingsService.todayDate();
    final result = <String, List<TimeSlot>>{};
    final bookings = <String, List<Booking>>{};
    for (final field in _fields) {
      try {
        result[field.id] =
            await BookingsService.instance.slotsFor(field, today);
        bookings[field.id] =
            await BookingsService.instance.fieldBookings(field.id, today);
      } catch (_) {
        result[field.id] = const [];
        bookings[field.id] = const [];
      }
    }

    // أرباح الأسبوع: من قبل ٦ أيام لليوم
    final week = <int>[];
    for (var i = 6; i >= 0; i--) {
      final date = DateLabels.dateFor(-i);
      var booked = 0;
      for (final field in _fields) {
        try {
          final slots = await BookingsService.instance.slotsFor(field, date);
          booked += slots.where((s) => s.isBooked).length;
        } catch (_) {
          // يوم ما انقرأ — يبقى صفر
        }
      }
      week.add(booked);
    }

    if (mounted) {
      setState(() {
        _slotsByField = result;
        _bookingsByField = bookings;
        _weekBookings = week;
      });
    }
  }

  /// إلغاء حجز لاعب — يسأل عن السبب، يسجّل الإلغاء، ويفتح واتساب للاعتذار
  Future<void> _cancelBooking(Field field, Booking booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.ownerCancelTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.ownerCancelBody,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.dark.withValues(alpha: 0.8),
                height: 1.7,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              // ما نسمح بأي رمز خطير بسبب الإلغاء
              inputFormatters: [InputSanitizer.deny()],
              maxLength: CancellationsService.reasonMaxLength,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: AppStrings.ownerCancelReasonHint,
                counterText: '',
                filled: true,
                fillColor: AppColors.subtleFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.ownerCancelKeep),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.ownerCancelConfirm),
          ),
        ],
      ),
    );

    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await CancellationsService.instance
          .cancelByOwner(field, booking, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ownerCancelDone)),
      );
      await _notifyPlayer(field, booking, reason);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ownerCancelError)),
      );
    }
  }

  /// اعتذار بالواتساب للاعب — بلهجة مهذّبة مع ذكر البديل والضمان
  Future<void> _notifyPlayer(
    Field field,
    Booking booking,
    String reason,
  ) async {
    if (booking.userPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ownerCancelNoPhone)),
      );
      return;
    }
    final message = AppStrings.ownerCancelWhatsapp(
      fieldName: field.name,
      dayLabel: DateLabels.label(booking.date),
      time: '${booking.hour.toString().padLeft(2, '0')}:00',
      reason: InputSanitizer.clean(
        reason,
        maxLength: CancellationsService.reasonMaxLength,
      ),
    );
    final phone = booking.userPhone.replaceAll('+', '');
    await launchUrl(
      Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// حجوزات اليوم عبر كل الملاعب
  int get _todayBooked {
    final slots = _slotsByField;
    if (slots == null) return 0;
    var count = 0;
    for (final list in slots.values) {
      count += list.where((s) => s.isBooked).length;
    }
    return count;
  }

  /// أوقات فاضية اليوم
  int get _todayFree {
    final slots = _slotsByField;
    if (slots == null) return 0;
    var count = 0;
    for (final list in slots.values) {
      count += list.where((s) => !s.isBooked).length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final slotsByField = _slotsByField;
    final deposit = FieldsService.depositAmount;
    final weekTotal = _weekBookings.fold(0, (a, b) => a + b) * deposit;
    final headerName = _fields.length == 1
        ? _fields.first.name
        : AppStrings.ownerFieldsCount(
            ArabicNum.count(_fields.length),
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // رأس غامق: رجوع + اسم الملعب + بطاقتا الأرباح
            Container(
              decoration: const BoxDecoration(
                color: AppColors.inkFixed,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Pressable(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.ownerWelcome,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.white
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  headerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          // أرباح اليوم — بطاقة خضراء
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.todayEarnings,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    ArabicNum.money(_todayBooked * deposit),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  Text(
                                    AppStrings.iqd,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white
                                          .withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // حجوزات اليوم — بطاقة شفافة
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.todayBookings,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    ArabicNum.count(_todayBooked),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  Text(
                                    AppStrings.freeSlotsCount(
                                      ArabicNum.count(_todayFree),
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // مخطط أرباح الأسبوع
            Container(
              margin: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.weekEarnings,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                      Text(
                        '${ArabicNum.money(weekTotal)} ${AppStrings.iqd}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _WeekChart(values: _weekBookings),
                ],
              ),
            ),
            // أوقات اليوم لكل ملعب
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
              child: Text(
                AppStrings.ownerTodayTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            if (slotsByField == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              for (final (i, field) in _fields.indexed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: _OwnerFieldCard(
                    field: field,
                    slots: slotsByField[field.id] ?? const [],
                    bookings: _bookingsByField[field.id] ?? const [],
                    onFieldChanged: (updated) =>
                        setState(() => _fields[i] = updated),
                    onCancelBooking: (booking) =>
                        _cancelBooking(field, booking),
                  ),
                ),
            // تلميح: سد الأوقات يصير بالحجز العادي
            Container(
              margin: const EdgeInsets.fromLTRB(22, 4, 22, 28),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.ownerHint,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// مخطط أعمدة لأرباح آخر ٧ أيام — أطول عمود أخضر غامق
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(0, (a, b) => b > a ? b : a);
    // أسماء الأيام من قبل ٦ أيام لليوم
    final labels = [
      for (var i = 6; i >= 0; i--)
        DateLabels.weekdayShort(DateLabels.dateFor(-i)),
    ];

    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // ارتفاع نسبي — أقل شي ٦ بكسل حتى يبين اليوم الفاضي
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    height: max == 0 ? 6 : 6 + (values[i] / max) * 104,
                    decoration: BoxDecoration(
                      color: values[i] == max && max > 0
                          ? AppColors.primary
                          : AppColors.primaryLight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          i == values.length - 1 ? FontWeight.w800 : FontWeight.w700,
                      color: i == values.length - 1
                          ? AppColors.dark
                          : AppColors.muted,
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

class _OwnerFieldCard extends StatelessWidget {
  const _OwnerFieldCard({
    required this.field,
    required this.slots,
    required this.bookings,
    required this.onFieldChanged,
    required this.onCancelBooking,
  });

  final Field field;
  final List<TimeSlot> slots;

  /// حجوزات اليوم — منها نلگه حجز الوقت اللي يضغط عليه المالك
  final List<Booking> bookings;
  final ValueChanged<Field> onFieldChanged;
  final ValueChanged<Booking> onCancelBooking;

  /// حجز هذا الوقت — null إذا الوقت فاضي أو الحجز مو محمّل
  Booking? _bookingAt(int hour) {
    for (final b in bookings) {
      if (b.hour == hour) return b;
    }
    return null;
  }

  void _openManage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldManageScreen(
          field: field,
          onChanged: onFieldChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookedCount = slots.where((s) => s.isBooked).length;
    final deposits = NumberFormat('#,###')
        .format(bookedCount * FieldsService.depositAmount);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس البطاقة: رسمة الملعب + اسمه
          SizedBox(
            height: 76,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FieldImage(field: field),
                // تدرّج غامق من الأسفل — الاسم يبقى واضح فوق أي صورة
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xB3000000), Colors.transparent],
                        stops: [0, 0.75],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 14,
                  bottom: 10,
                  child: Text(
                    field.name,
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                // زر إدارة الملعب — معلومات ووسائط وطرق دفع
                PositionedDirectional(
                  end: 10,
                  top: 10,
                  child: Pressable(
                    onTap: () => _openManage(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_rounded,
                            size: 15,
                            color: AppColors.primaryDeep,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            AppStrings.manageFieldAction,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkFixed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // إحصائيات اليوم
                Row(
                  children: [
                    _StatBox(
                      icon: Icons.event_available_rounded,
                      value: '$bookedCount',
                      label: AppStrings.bookingsCountLabel,
                    ),
                    const SizedBox(width: 10),
                    _StatBox(
                      icon: Icons.payments_outlined,
                      value: '$deposits ${AppStrings.iqd}',
                      label: AppStrings.depositsLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // شبكة الأوقات — الوقت المحجوز يُضغط لإلغائه
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final slot in slots)
                      Builder(
                        builder: (context) {
                          final booking =
                              slot.isBooked ? _bookingAt(slot.hour) : null;
                          final chip = Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: slot.isBooked
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: slot.isBooked
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  slot.label,
                                  textDirection: TextDirection.ltr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    color: slot.isBooked
                                        ? AppColors.white
                                        : AppColors.dark,
                                  ),
                                ),
                                Text(
                                  slot.isBooked
                                      ? (booking == null
                                          ? AppStrings.bookedLabel
                                          : AppStrings.ownerCancelSlotAction)
                                      : AppStrings.freeLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    color: slot.isBooked
                                        ? AppColors.white
                                            .withValues(alpha: 0.9)
                                        : AppColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );

                          // بس الأوقات اللي نعرف حجزها تنضغط للإلغاء
                          if (booking == null) return chip;
                          return Pressable(
                            key: Key('owner-slot-${field.id}-${slot.hour}'),
                            onTap: () => onCancelBooking(booking),
                            child: chip,
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primaryDeep),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.dark,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
