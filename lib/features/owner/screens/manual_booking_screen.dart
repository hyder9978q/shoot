import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/pressable.dart';

/// حجز يدوي — لزبون حجز خارج التطبيق (تلفون/واتساب/حضور مباشر).
///
/// يحجز نفس الوقت بنفس آلية منع الحجز المزدوج للحجز العادي بالضبط
/// (معرّف المستند fieldId_date_hour) — ما أحد يگدر ياخذ نفس الوقت
/// من التطبيق بعدها.
class ManualBookingScreen extends StatefulWidget {
  const ManualBookingScreen({super.key, required this.fields});

  /// ملاعب هذا المالك — يختار وحد منها إذا أكثر من ملعب
  final List<Field> fields;

  @override
  State<ManualBookingScreen> createState() => _ManualBookingScreenState();
}

class _ManualBookingScreenState extends State<ManualBookingScreen> {
  late Field _field = widget.fields.first;
  String _date = BookingsService.todayDate();
  int? _hour;
  List<TimeSlot>? _slots;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _slots = null;
      _hour = null;
    });
    final slots = await BookingsService.instance.slotsFor(_field, _date);
    if (mounted) setState(() => _slots = slots);
  }

  void _pickField(Field field) {
    if (field.id == _field.id) return;
    setState(() => _field = field);
    _loadSlots();
  }

  void _pickDate(String date) {
    if (date == _date) return;
    setState(() => _date = date);
    _loadSlots();
  }

  Future<void> _submit() async {
    final hour = _hour;
    if (hour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.manualBookingPickTimeFirst)),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = AppStrings.manualBookingNameRequired);
      return;
    }
    if (_saving) return;
    setState(() {
      _nameError = null;
      _saving = true;
    });

    try {
      await BookingsService.instance.createManualBooking(
        _field,
        TimeSlot(hour: hour, isBooked: false),
        date: _date,
        customerName: name,
        customerPhone: _phoneController.text,
        note: _noteController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.manualBookingSuccess)),
      );
      Navigator.of(context).pop(true);
    } on SlotTakenException {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.slotTakenError)));
      await _loadSlots();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.manualBookingError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    final slots = _slots;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.manualBookingTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
            child: Pressable(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: AppColors.primaryShadow,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(AppStrings.manualBookingConfirm),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
        children: [
          Text(
            AppStrings.manualBookingSubtitle,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),

          // الملعب — يبين فقط لو المالك عنده أكثر من ملعب
          if (widget.fields.length > 1) ...[
            Text(AppStrings.manualBookingFieldLabel, style: labelStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in widget.fields)
                  _ChoiceChip(
                    label: field.name,
                    selected: field.id == _field.id,
                    onTap: () => _pickField(field),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // اليوم
          Text(AppStrings.manualBookingDateLabel, style: labelStyle),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
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
          const SizedBox(height: 24),

          // الوقت
          Text(AppStrings.manualBookingTimeLabel, style: labelStyle),
          const SizedBox(height: 10),
          if (slots == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (slots.every((s) => s.isBooked))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                AppStrings.manualBookingNoSlots,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in slots)
                  _ChoiceChip(
                    label: TimeLabels.hour12(slot.hour),
                    selected: _hour == slot.hour,
                    disabled: slot.isBooked,
                    onTap: slot.isBooked
                        ? null
                        : () => setState(() => _hour = slot.hour),
                  ),
              ],
            ),
          const SizedBox(height: 24),

          // اسم الزبون
          Text(AppStrings.manualBookingCustomerNameLabel, style: labelStyle),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            inputFormatters: [InputSanitizer.deny()],
            decoration: InputDecoration(
              counterText: '',
              hintText: AppStrings.manualBookingCustomerNameHint,
              errorText: _nameError,
              prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),

          // رقم الزبون (اختياري)
          Text(AppStrings.manualBookingCustomerPhoneLabel, style: labelStyle),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            maxLength: 20,
            inputFormatters: [InputSanitizer.deny()],
            decoration: InputDecoration(
              counterText: '',
              hintText: AppStrings.manualBookingCustomerPhoneHint,
              hintTextDirection: TextDirection.ltr,
              prefixIcon: Icon(Icons.call_outlined, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),

          // ملاحظة (اختياري)
          Text(AppStrings.manualBookingNoteLabel, style: labelStyle),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLength: 120,
            maxLines: 2,
            minLines: 1,
            inputFormatters: [InputSanitizer.deny()],
            decoration: InputDecoration(
              counterText: '',
              hintText: AppStrings.manualBookingNoteHint,
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شيب يوم — نفس ستايل شيب اليوم بصفحة تفاصيل الملعب
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

/// شيب اختيار — معطّل (مشطوب خفيف) للأوقات المحجوزة
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            decoration: disabled ? TextDecoration.lineThrough : null,
            decorationColor: AppColors.muted,
            color: disabled
                ? AppColors.muted
                : selected
                ? AppColors.white
                : AppColors.dark,
          ),
        ),
      ),
    );
  }
}
