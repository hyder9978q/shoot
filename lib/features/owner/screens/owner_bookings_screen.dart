import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/booking.dart';
import '../../../core/models/field.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/widgets/pressable.dart';
import '../utils/owner_booking_actions.dart';

/// تبويب "الحجوزات" — كل حجوزات صاحب المنشأة عبر منشآته كلها، بقائمة
/// زمنية وحدة (بدل تصفّح يوم بيوم مثل لوحة التحكم)، مع تبديل
/// القادمة/السابقة.
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key, required this.fields});

  final List<Field> fields;

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  bool _upcoming = true;
  List<Booking>? _bookings;

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

  @override
  void didUpdateWidget(covariant OwnerBookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fields.length != widget.fields.length) _load();
  }

  Future<void> _load() async {
    final ids = [for (final f in widget.fields) f.id];
    final list = await BookingsService.instance.ownerBookings(
      ids,
      upcoming: _upcoming,
    );
    if (mounted) setState(() => _bookings = list);
  }

  void _switch(bool upcoming) {
    if (upcoming == _upcoming) return;
    setState(() {
      _upcoming = upcoming;
      _bookings = null;
    });
    _load();
  }

  Field? _fieldFor(String fieldId) {
    for (final f in widget.fields) {
      if (f.id == fieldId) return f;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bookings = _bookings;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.ownerBookingsTitle),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            _Segmented(
              upcoming: _upcoming,
              onChanged: _switch,
            ),
            const SizedBox(height: 16),
            if (bookings == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (bookings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    _upcoming
                        ? AppStrings.ownerBookingsEmptyUpcoming
                        : AppStrings.ownerBookingsEmptyPast,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              )
            else
              for (final booking in bookings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BookingCard(
                    booking: booking,
                    onCancel: _upcoming && _fieldFor(booking.fieldId) != null
                        ? () => OwnerBookingActions.handle(
                            context,
                            _fieldFor(booking.fieldId)!,
                            booking,
                            onDone: _load,
                          )
                        : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.upcoming, required this.onChanged});

  final bool upcoming;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              label: AppStrings.ownerBookingsUpcoming,
              selected: upcoming,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _SegmentTab(
              label: AppStrings.ownerBookingsPast,
              selected: !upcoming,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.dark : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.onCancel});

  final Booking booking;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: booking.isManual
                  ? AppColors.accentSoft
                  : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              booking.isManual
                  ? Icons.edit_calendar_rounded
                  : Icons.event_available_rounded,
              size: 21,
              color: booking.isManual
                  ? AppColors.accentInk
                  : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                    if (booking.isManual)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppStrings.manualBadge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentInk,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateLabels.label(booking.date)} · ${booking.timeLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                  ),
                ),
                if (booking.isManual && booking.customerName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    booking.customerName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCancel != null)
            Pressable(
              onTap: onCancel,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
