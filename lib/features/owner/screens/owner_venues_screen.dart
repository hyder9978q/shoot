import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/pressable.dart';
import 'add_venue_screen.dart';
import 'field_manage_screen.dart';

/// تبويب "منشآتي" — كل منشآت صاحب الحساب بمكان واحد، وزر إضافة منشأة
/// جديدة. الضغط على أي منشأة يفتح إدارتها الكاملة (معلومات، صور،
/// طرق دفع، خدمات).
class OwnerVenuesScreen extends StatelessWidget {
  const OwnerVenuesScreen({
    super.key,
    required this.fields,
    required this.onChanged,
  });

  final List<Field> fields;

  /// ينستدعى بعد إضافة منشأة جديدة أو تعديل منشأة موجودة
  final VoidCallback onChanged;

  Future<void> _addVenue(BuildContext context) async {
    final added = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddVenueScreen()));
    if (added == true) onChanged();
  }

  void _manage(BuildContext context, Field field) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldManageScreen(
          field: field,
          onChanged: (_) => onChanged(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.myVenuesTitle),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: Pressable(
              onTap: () => _addVenue(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 17, color: AppColors.white),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.addVenueAction,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: fields.isEmpty
          ? _EmptyVenues(onAdd: () => _addVenue(context))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              itemCount: fields.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _VenueCard(
                  field: fields[i],
                  onTap: () => _manage(context, fields[i]),
                ),
              ),
            ),
    );
  }
}

class _EmptyVenues extends StatelessWidget {
  const _EmptyVenues({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 56,
              color: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.noVenuesTitle,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.noVenuesMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Pressable(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.primaryShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.white),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.addVenueAction,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
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

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.field, required this.onTap});

  final Field field;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: FieldImage(field: field),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            field.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        if (!field.isOpen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppStrings.fieldClosedBadge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(field.sport.icon, size: 14, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          field.sport.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      field.location,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${TimeLabels.hour12(field.openHour)} - ${TimeLabels.hour12(field.closeHour == 24 ? 0 : field.closeHour)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (field.contactPhone.isEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: AppColors.accentInk,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              AppStrings.venueContactPhoneRequired,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Icon(
                Icons.chevron_left_rounded,
                color: AppColors.border,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
