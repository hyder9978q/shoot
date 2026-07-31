import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/pressable.dart';

/// مراجعة المنشآت الجديدة — للمسؤول فقط.
///
/// كل منشأة يسجّلها صاحبها تنولد معطّلة (isActive == false): ما تبين
/// بالبحث ولا بالخريطة ولا تنحجز. من هنا يشوفها المسؤول ويفعّلها بعد ما
/// يتأكد منها. قواعد Firestore تمنع أي حد ثاني من التفعيل.
class AdminPendingVenuesScreen extends StatefulWidget {
  const AdminPendingVenuesScreen({super.key});

  @override
  State<AdminPendingVenuesScreen> createState() =>
      _AdminPendingVenuesScreenState();
}

class _AdminPendingVenuesScreenState extends State<AdminPendingVenuesScreen> {
  List<Field>? _pending;

  /// المنشآت اللي تفعيلها جاري — منع الضغط المكرر
  final Set<String> _activating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await FieldsService.instance.pendingFields();
      if (mounted) setState(() => _pending = list);
    } catch (_) {
      if (mounted) setState(() => _pending = const []);
    }
  }

  Future<void> _activate(Field field) async {
    if (!_activating.add(field.id)) return;
    setState(() {});
    try {
      await FieldsService.instance.setFieldActive(field, true);
      if (!mounted) return;
      setState(() {
        _pending = [
          for (final f in _pending ?? const <Field>[])
            if (f.id != field.id) f,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.adminVenueActivated)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.adminVenueActivateError)),
      );
    } finally {
      _activating.remove(field.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.adminPendingVenuesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: pending == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: pending.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Text(
                              AppStrings.adminNoPendingVenues,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                      itemCount: pending.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Text(
                            AppStrings.adminPendingVenuesSubtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                              height: 1.6,
                            ),
                          );
                        }
                        final field = pending[i - 1];
                        return _PendingVenueCard(
                          key: Key('pending-venue-${field.id}'),
                          field: field,
                          busy: _activating.contains(field.id),
                          onActivate: () => _activate(field),
                        );
                      },
                    ),
            ),
    );
  }
}

class _PendingVenueCard extends StatelessWidget {
  const _PendingVenueCard({
    super.key,
    required this.field,
    required this.busy,
    required this.onActivate,
  });

  final Field field;
  final bool busy;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  field.sport.icon,
                  size: 18,
                  color: AppColors.accentInk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${field.sport.label} · ${field.location}',
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
          const SizedBox(height: 10),
          Text(
            '${TimeLabels.hour12(field.openHour)} - '
            '${TimeLabels.hour12(field.closeHour == 24 ? 0 : field.closeHour)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          if (field.contactPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Pressable(
              onTap: () => launchUrl(Uri.parse('tel:${field.contactPhone}')),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${AppStrings.adminVenueOwnerPhone}: '
                      '${field.contactPhone}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 46),
              ),
              onPressed: busy ? null : onActivate,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      AppStrings.adminActivateVenueAction,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
