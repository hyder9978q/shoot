import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/widgets/pressable.dart';
import 'booking_success_screen.dart';

/// طرق الدفع المعروضة (شاشة ٠٧ بالتصميم)
/// ملاحظة: بوابات الدفع بعدها ما مربوطة — الاختيار عرض فقط
/// والعربون يتأكد بالملعب لحد ما نفعّل زين كاش.
enum PayMethod { zainCash, card }

/// شاشة تأكيد الحجز والدفع — ملخص + طريقة دفع + زر العربون
class BookingCheckoutScreen extends StatefulWidget {
  const BookingCheckoutScreen({
    super.key,
    required this.field,
    required this.slot,
    required this.date,
  });

  final Field field;
  final TimeSlot slot;
  final String date;

  @override
  State<BookingCheckoutScreen> createState() => _BookingCheckoutScreenState();
}

class _BookingCheckoutScreenState extends State<BookingCheckoutScreen> {
  PayMethod _method = PayMethod.zainCash;
  bool _paying = false;

  int get _deposit => FieldsService.depositAmount;
  int get _rest => widget.field.pricePerHour - _deposit;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      await BookingsService.instance
          .createBooking(widget.field, widget.slot, date: widget.date);
    } on SlotTakenException {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.slotTakenError)),
      );
      // الوقت انحجز من غيرنا — نرجع للتفاصيل حتى يختار وقت ثاني
      Navigator.of(context).pop();
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.bookingError)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _paying = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookingSuccessScreen(
          field: widget.field,
          slot: widget.slot,
          date: widget.date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final hour = '${widget.slot.hour.toString().padLeft(2, '0')}:00';

    return Scaffold(
      backgroundColor: AppColors.background,
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
            child: Pressable(
              onTap: _paying ? null : _pay,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _paying
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.primaryShadow,
                ),
                child: _paying
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        '${AppStrings.payDeposit} '
                        '${ArabicNum.money(_deposit)} ${AppStrings.iqd}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // رأس أبيض: رجوع + عنوان
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.subtleFill,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    AppStrings.confirmBookingTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ملخص الحجز
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.bookingSummary,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SummaryLine(
                            label: AppStrings.fieldLabel,
                            value: field.name,
                          ),
                          _SummaryLine(
                            label: AppStrings.dateTimeLabel,
                            value: '${DateLabels.label(widget.date)} · $hour',
                          ),
                          _SummaryLine(
                            label: AppStrings.hourPriceLabel,
                            value: '${ArabicNum.money(field.pricePerHour)} '
                                '${AppStrings.iqd}',
                          ),
                          const SizedBox(height: 4),
                          Divider(color: AppColors.hairline, height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppStrings.depositNow,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dark,
                                  ),
                                ),
                              ),
                              Text(
                                '${ArabicNum.money(_deposit)} ${AppStrings.iqd}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            AppStrings.restAtField(
                              '${ArabicNum.money(_rest)} ${AppStrings.iqd}',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      AppStrings.payMethodTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PayRow(
                      selected: _method == PayMethod.zainCash,
                      onTap: () =>
                          setState(() => _method = PayMethod.zainCash),
                      title: AppStrings.zainCash,
                      subtitle: AppStrings.zainCashHint,
                      leading: Container(
                        width: 40,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.inkFixed,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'زين',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFACC15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PayRow(
                      selected: _method == PayMethod.card,
                      onTap: () => setState(() => _method = PayMethod.card),
                      title: AppStrings.cardPay,
                      subtitle: AppStrings.cardPayHint,
                      leading: Container(
                        width: 40,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.subtleFill,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.credit_card_rounded,
                          size: 18,
                          color: AppColors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // الدفع الإلكتروني بعده ما مفعّل — نكون صريحين
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        AppStrings.depositNote,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentInk,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر بالملخص: تسمية رمادية + قيمة غامقة
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// صف طريقة دفع — مختار = حد أخضر وعلامة صح
class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.leading,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.hairline,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: selected
                    ? null
                    : Border.all(color: AppColors.border, width: 2),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: AppColors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
