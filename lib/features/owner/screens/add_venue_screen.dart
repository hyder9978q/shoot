import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/pressable.dart';

/// إضافة منشأة جديدة لصاحب الحساب — ملعب، صالة رياضية، مسبح، مركز
/// علاج رياضي، أو أي مكان رياضي (نفس [Sport] المستخدمة بكل التطبيق).
/// الصور وطرق الدفع تُكمّل بعدين من "إدارة المنشأة".
class AddVenueScreen extends StatefulWidget {
  const AddVenueScreen({super.key});

  @override
  State<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends State<AddVenueScreen> {
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();

  Sport _sport = Sport.football;
  int _openHour = 16;
  int _closeHour = 24;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_nameController.text.trim().isEmpty) {
      _snack(AppStrings.fieldNameError);
      return;
    }
    if (_areaController.text.trim().isEmpty) {
      _snack(AppStrings.areaError);
      return;
    }
    if (_cityController.text.trim().isEmpty) {
      _snack(AppStrings.cityError);
      return;
    }
    final price = int.tryParse(_priceController.text.trim());
    if (price == null || price <= 0 || price > 1000000) {
      _snack(AppStrings.priceError);
      return;
    }
    if (_openHour >= _closeHour) {
      _snack(AppStrings.hoursError);
      return;
    }
    if (!AuthService.isValidIraqiPhone(_phoneController.text.trim())) {
      _snack(AppStrings.venueContactPhoneError);
      return;
    }

    setState(() => _saving = true);
    try {
      await FieldsService.instance.createField(
        name: _nameController.text,
        area: _areaController.text,
        city: _cityController.text,
        sport: _sport,
        pricePerHour: price,
        openHour: _openHour,
        closeHour: _closeHour,
        contactPhone: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.venueAdded)));
      Navigator.of(context).pop(true);
    } on ArgumentError {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(AppStrings.venueAddError);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(AppStrings.venueAddError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.addVenueTitle),
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
                      : const Text(AppStrings.addVenueSubmit),
                ),
              ),
            ),
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          children: [
            Text(
              AppStrings.addVenueSubtitle,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            _Label(AppStrings.venueTypeLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sport in Sport.values)
                  _SportPill(
                    label: sport.label,
                    icon: sport.icon,
                    selected: _sport == sport,
                    onTap: () => setState(() => _sport = sport),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _Label(AppStrings.fieldNameLabel),
            TextField(
              controller: _nameController,
              maxLength: 50,
              inputFormatters: [InputSanitizer.deny()],
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label(AppStrings.areaLabel),
                      TextField(
                        controller: _areaController,
                        maxLength: 50,
                        inputFormatters: [InputSanitizer.deny()],
                        decoration: const InputDecoration(counterText: ''),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label(AppStrings.cityLabel),
                      TextField(
                        controller: _cityController,
                        maxLength: 30,
                        inputFormatters: [InputSanitizer.deny()],
                        decoration: const InputDecoration(counterText: ''),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Label(AppStrings.priceLabel),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              maxLength: 7,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 16),
            _Label(AppStrings.workingHoursLabel),
            Row(
              children: [
                Expanded(
                  child: _HourPicker(
                    label: AppStrings.opensAtLabel,
                    value: _openHour,
                    min: 0,
                    max: 23,
                    onChanged: (v) => setState(() => _openHour = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HourPicker(
                    label: AppStrings.closesAtLabel,
                    value: _closeHour,
                    min: 1,
                    max: 24,
                    onChanged: (v) => setState(() => _closeHour = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Label(AppStrings.venueContactPhoneLabel),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 11,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                InputSanitizer.deny(),
              ],
              decoration: const InputDecoration(
                counterText: '',
                hintText: AppStrings.venueContactPhoneHint,
                hintTextDirection: TextDirection.ltr,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.venueContactPhoneDesc,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: AppColors.grey,
        ),
      ),
    );
  }
}

class _SportPill extends StatelessWidget {
  const _SportPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.white : AppColors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.white : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value.clamp(min, max),
              isExpanded: true,
              borderRadius: BorderRadius.circular(14),
              items: [
                for (var h = min; h <= max; h++)
                  DropdownMenuItem(
                    value: h,
                    child: Text(
                      TimeLabels.hour12(h),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
