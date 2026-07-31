import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/field.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/services/cancellations_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/time_labels.dart';

/// إلغاء حجز من صاحب المنشأة — حجز يدوي أو حقيقي، بنفس منطق التأكيد
/// والاعتذار بالواتساب. تستخدمها لوحة التحكم وتبويب الحجوزات كلاهما.
class OwnerBookingActions {
  OwnerBookingActions._();

  /// الضغط على حجز: يدوي يتحذف مباشرة، وحقيقي يمر بحوار الاعتذار
  static Future<void> handle(
    BuildContext context,
    Field field,
    Booking booking, {
    required VoidCallback onDone,
  }) {
    return booking.isManual
        ? _cancelManual(context, field, booking, onDone: onDone)
        : _cancelReal(context, field, booking, onDone: onDone);
  }

  static Future<void> _cancelManual(
    BuildContext context,
    Field field,
    Booking booking, {
    required VoidCallback onDone,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteManualBookingTitle),
        content: Text(
          AppStrings.deleteManualBookingConfirm,
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
    if (confirmed != true || !context.mounted) return;

    try {
      await BookingsService.instance.cancelManualBooking(field, booking);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.manualBookingDeleted)),
      );
      onDone();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.manualBookingDeleteError)),
      );
    }
  }

  static Future<void> _cancelReal(
    BuildContext context,
    Field field,
    Booking booking, {
    required VoidCallback onDone,
  }) async {
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
    if (confirmed != true || !context.mounted) return;

    try {
      // رقم اللاعب بمستنده الخاص — نجيبه قبل الإلغاء لأن المستند
      // ينحذف مع الحجز، وبيه نرسل الاعتذار بالواتساب بعدها
      final withPhone = await BookingsService.instance.withContact(booking);
      await CancellationsService.instance.cancelByOwner(
        field,
        booking,
        reason: reason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.ownerCancelDone)));
      await _notifyPlayer(context, field, withPhone, reason);
      onDone();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ownerCancelError)),
      );
    }
  }

  /// اعتذار بالواتساب للاعب — بلهجة مهذّبة مع ذكر البديل والضمان
  static Future<void> _notifyPlayer(
    BuildContext context,
    Field field,
    Booking booking,
    String reason,
  ) async {
    if (booking.userPhone.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.ownerCancelNoPhone)),
      );
      return;
    }
    final message = AppStrings.ownerCancelWhatsapp(
      fieldName: field.name,
      dayLabel: DateLabels.label(booking.date),
      time: TimeLabels.hour12(booking.hour),
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
}
