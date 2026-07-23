import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/pressable.dart';

/// شاشة نجاح الحجز — تذكرة الحجز (شاشة ٠٨ بالتصميم)
class BookingSuccessScreen extends StatefulWidget {
  BookingSuccessScreen({
    super.key,
    required this.field,
    required this.slot,
    String? date,
  }) : date = date ?? BookingsService.todayDate();

  final Field field;
  final TimeSlot slot;

  /// يوم الحجز yyyy-MM-dd
  final String date;

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // البداية من 0.85 مو من الصفر — العناصر الحقيقية ما تظهر من العدم
    _scale = Tween<double>(
      begin: 0.85,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// رقم التذكرة — مشتق من معرّف الحجز حتى يطابق اللي بقاعدة البيانات
  String get _ticketCode {
    final raw = '${widget.field.id}${widget.date}${widget.slot.hour}';
    final number = raw.hashCode.abs() % 9000 + 1000;
    return 'SH-$number';
  }

  void _sendWhatsapp() {
    final deposit = ArabicNum.money(FieldsService.depositAmount);
    final message =
        'تم الحجز ✅\n'
        '🏟️ ${widget.field.name} — ${widget.field.location}\n'
        '🕐 ${DateLabels.label(widget.date)} ${widget.slot.label}\n'
        '🎟️ رقم التذكرة: $_ticketCode\n'
        '💵 العربون: $deposit ${AppStrings.iqd} (مدفوع) والباقي كاش بالملعب\n'
        '— عن طريق تطبيق شوت ⚽';
    // رقم تواصل المنشأة العام إذا موجود — التأكيد يوصل مباشرة إلها
    final contactPhone = widget.field.contactPhone;
    final target = contactPhone.isEmpty
        ? ''
        : contactPhone.replaceAll('+', '');
    launchUrl(
      Uri.parse('https://wa.me/$target?text=${Uri.encodeComponent(message)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final hour = TimeLabels.hour12(widget.slot.hour);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 40, 26, 24),
                  child: Column(
                    children: [
                      // دائرة النجاح: هالة خضراء فاتحة + قرص أخضر + صح أبيض
                      FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          child: Container(
                            width: 120,
                            height: 120,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 84,
                              height: 84,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 30,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 46,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        AppStrings.bookingSuccessTitle,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.bookingSuccessSub(field.name),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 28),
                      // التذكرة
                      Container(
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          children: [
                            // رأس التذكرة الأخضر
                            Container(
                              color: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      AppStrings.ticketTitle,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '#$_ticketCode',
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                18,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _TicketCell(
                                          label: AppStrings.fieldLabel,
                                          value: field.name,
                                        ),
                                      ),
                                      Expanded(
                                        child: _TicketCell(
                                          label: AppStrings.ticketSportLabel,
                                          value:
                                              '${field.sport.label} '
                                              '${field.sizeText}',
                                          alignEnd: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _TicketCell(
                                          label: AppStrings.dateLabel,
                                          value: DateLabels.label(widget.date),
                                        ),
                                      ),
                                      Expanded(
                                        child: _TicketCell(
                                          label: AppStrings.timeLabel,
                                          value: hour,
                                          alignEnd: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // فاصل مقصوص (زي التذاكر)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 15),
                                    child: _DashedLine(),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          AppStrings.paidDeposit,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${ArabicNum.money(FieldsService.depositAmount)}'
                                        ' ${AppStrings.iqd}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
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
                      const SizedBox(height: 14),
                      Text(
                        AppStrings.bookingSuccessNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                          height: 1.7,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      // إرسال ملخص الحجز على واتساب (يختار المستخدم المحادثة)
                      Pressable(
                        onTap: _sendWhatsapp,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppColors.primaryShadow,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_rounded,
                                size: 20,
                                color: AppColors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                AppStrings.sendWhatsappConfirm,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Pressable(
                        onTap: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            AppStrings.backHome,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// خانة بالتذكرة: تسمية صغيرة فوق قيمة غامقة
class _TicketCell extends StatelessWidget {
  const _TicketCell({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
      ],
    );
  }
}

/// خط متقطّع بعرض التذكرة
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: CustomPaint(
        size: const Size(double.infinity, 2),
        painter: _DashedLinePainter(color: AppColors.border),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 6.0;
    const gap = 5.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 1), Offset(x + dash, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
