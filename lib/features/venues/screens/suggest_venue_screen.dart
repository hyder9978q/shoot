import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/venue_suggestions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/widgets/pressable.dart';

/// نموذج "اقترح ملعب" — اللاعب يبلغ عن ملعب/منشأة ما موجودة بالتطبيق.
/// إذا نفس الملعب مقترح من لاعبين ثانين نزيد عدّاد الطلبات بس (الخدمة
/// تتكفل بالتطابق التقريبي)، والرسالة تختلف حسب النتيجة.
class SuggestVenueScreen extends StatefulWidget {
  const SuggestVenueScreen({super.key});

  @override
  State<SuggestVenueScreen> createState() => _SuggestVenueScreenState();
}

class _SuggestVenueScreenState extends State<SuggestVenueScreen> {
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _mapsUrlController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  String? _nameError;
  String? _areaError;
  bool _posting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _mapsUrlController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_posting) return;
    final name = _nameController.text.trim();
    final area = _areaController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? AppStrings.fieldNameError : null;
      _areaError = area.isEmpty ? AppStrings.suggestAreaError : null;
    });
    if (name.isEmpty || area.isEmpty) return;

    final mapsUrl = _mapsUrlController.text.trim();
    if (mapsUrl.isNotEmpty && !mapsUrl.startsWith('https://')) {
      _snack(AppStrings.suggestMapsUrlError);
      return;
    }
    final phoneDigits = _phoneController.text.trim();
    if (phoneDigits.isNotEmpty &&
        !RegExp(r'^07\d{9}$').hasMatch(phoneDigits)) {
      _snack(AppStrings.phoneError);
      return;
    }

    setState(() => _posting = true);
    try {
      final isNew = await VenueSuggestionsService.instance.suggestVenue(
        name: name,
        area: area,
        mapsUrl: mapsUrl,
        phone: phoneDigits,
        note: _noteController.text,
      );
      if (!mounted) return;
      _snack(
        isNew
            ? AppStrings.suggestThankYouNew
            : AppStrings.suggestThankYouDuplicate,
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      _snack(AppStrings.suggestVenueError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.suggestVenueTitle),
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
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
                child: ElevatedButton(
                  onPressed: _posting ? null : _submit,
                  child: _posting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(AppStrings.suggestSubmitAction),
                ),
              ),
            ),
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _posting,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.stadium_rounded,
                    size: 22,
                    color: AppColors.primaryDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.suggestVenueIntro,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(AppStrings.fieldNameLabel, style: labelStyle),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              maxLength: 50,
              inputFormatters: [InputSanitizer.deny()],
              decoration: InputDecoration(
                counterText: '',
                errorText: _nameError,
                prefixIcon: Icon(
                  Icons.stadium_outlined,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(AppStrings.suggestAreaLabel, style: labelStyle),
            const SizedBox(height: 10),
            TextField(
              controller: _areaController,
              textInputAction: TextInputAction.next,
              maxLength: 50,
              inputFormatters: [InputSanitizer.deny()],
              decoration: InputDecoration(
                counterText: '',
                hintText: AppStrings.suggestAreaHint,
                errorText: _areaError,
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(AppStrings.suggestMapsUrlLabel, style: labelStyle),
            const SizedBox(height: 10),
            TextField(
              controller: _mapsUrlController,
              textInputAction: TextInputAction.next,
              textDirection: TextDirection.ltr,
              maxLength: 500,
              inputFormatters: [InputSanitizer.deny()],
              decoration: InputDecoration(
                counterText: '',
                hintText: AppStrings.suggestMapsUrlHint,
                hintTextDirection: TextDirection.ltr,
                prefixIcon: Icon(Icons.map_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),

            Text(AppStrings.suggestPhoneLabel, style: labelStyle),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 11,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                InputSanitizer.deny(),
              ],
              decoration: InputDecoration(
                counterText: '',
                hintText: AppStrings.phoneHint,
                hintTextDirection: TextDirection.ltr,
                prefixIcon: Icon(Icons.call_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),

            Text(AppStrings.noteLabel, style: labelStyle),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 200,
              inputFormatters: [InputSanitizer.deny()],
              decoration: const InputDecoration(
                hintText: AppStrings.suggestNoteHint,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
