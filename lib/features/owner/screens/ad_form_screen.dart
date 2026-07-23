import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/ad.dart';
import '../../../core/models/field.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/widgets/pressable.dart';

/// نشر إعلان جديد أو تعديل إعلان موجود — [existing] فارغ = نشر جديد.
class AdFormScreen extends StatefulWidget {
  const AdFormScreen({super.key, required this.fields, this.existing});

  /// منشآت المالك — يختار منها إذا أكثر من وحدة
  final List<Field> fields;

  /// الإعلان المطلوب تعديله — null يعني نشر إعلان جديد
  final Ad? existing;

  @override
  State<AdFormScreen> createState() => _AdFormScreenState();
}

class _AdFormScreenState extends State<AdFormScreen> {
  late Field _field = widget.existing == null
      ? widget.fields.first
      : widget.fields.firstWhere(
          (f) => f.id == widget.existing!.fieldId,
          orElse: () => widget.fields.first,
        );

  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _bodyController = TextEditingController(
    text: widget.existing?.body ?? '',
  );

  late AdType _type = widget.existing?.type ?? AdType.promo;
  late String _expiresAt = widget.existing?.expiresAt ?? DateLabels.dateFor(7);
  late String _imageUrl = widget.existing?.imageUrl ?? '';

  bool _uploadingImage = false;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingImage = true);
    try {
      final ownerId = _field.ownerId;
      final url = await AdsService.instance.uploadAdImage(ownerId, file);
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } on InvalidImageException catch (e) {
      if (!mounted) return;
      _snack(
        e.tooLarge ? AppStrings.photoTooLarge : AppStrings.photoInvalidType,
      );
    } on StateError {
      if (!mounted) return;
      _snack(AppStrings.photosNeedLiveApp);
    } catch (_) {
      if (!mounted) return;
      _snack(AppStrings.photoUploadError);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_titleController.text.trim().isEmpty) {
      _snack(AppStrings.adTitleError);
      return;
    }
    if (_bodyController.text.trim().isEmpty) {
      _snack(AppStrings.adBodyError);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editing) {
        await AdsService.instance.updateAd(
          widget.existing!,
          title: _titleController.text,
          body: _bodyController.text,
          type: _type,
          expiresAt: _expiresAt,
          imageUrl: _imageUrl,
        );
      } else {
        await AdsService.instance.createAd(
          _field,
          title: _titleController.text,
          body: _bodyController.text,
          type: _type,
          expiresAt: _expiresAt,
          imageUrl: _imageUrl,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? AppStrings.adSaved : AppStrings.adPublished),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(AppStrings.adPublishError);
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
        title: Text(_editing ? AppStrings.editAdTitle : AppStrings.addAdTitle),
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
                      : Text(
                          _editing
                              ? AppStrings.saveAdAction
                              : AppStrings.publishAdAction,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
        children: [
          if (!_editing && widget.fields.length > 1) ...[
            Text(AppStrings.adVenueLabel, style: labelStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in widget.fields)
                  _ChoiceChip(
                    label: field.name,
                    selected: field.id == _field.id,
                    onTap: () => setState(() => _field = field),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          Text(AppStrings.adTypeLabel, style: labelStyle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in AdType.values)
                _ChoiceChip(
                  label: type.label,
                  icon: type.icon,
                  selected: _type == type,
                  onTap: () => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(AppStrings.adTitleLabel, style: labelStyle),
          const SizedBox(height: 10),
          TextField(
            controller: _titleController,
            maxLength: AdsService.titleMaxLength,
            inputFormatters: [InputSanitizer.deny()],
            decoration: const InputDecoration(
              counterText: '',
              hintText: AppStrings.adTitleHint,
            ),
          ),
          const SizedBox(height: 24),
          Text(AppStrings.adBodyLabel, style: labelStyle),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyController,
            maxLength: AdsService.bodyMaxLength,
            maxLines: 4,
            minLines: 3,
            inputFormatters: [InputSanitizer.deny()],
            decoration: const InputDecoration(
              counterText: '',
              hintText: AppStrings.adBodyHint,
            ),
          ),
          const SizedBox(height: 24),
          Text(AppStrings.adImageLabel, style: labelStyle),
          const SizedBox(height: 10),
          _ImagePickerBox(
            imageUrl: _imageUrl,
            uploading: _uploadingImage,
            onTap: _uploadingImage ? null : _pickImage,
            onRemove: _imageUrl.isEmpty
                ? null
                : () => setState(() => _imageUrl = ''),
          ),
          const SizedBox(height: 24),
          Text(AppStrings.adExpiryLabel, style: labelStyle),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 60,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final date = DateLabels.dateFor(i);
                return _DayChip(
                  date: date,
                  selected: _expiresAt == date,
                  onTap: () => setState(() => _expiresAt = date),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// شيب يوم — نفس ستايل شيب اليوم بشاشة الحجز اليدوي
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

/// شيب اختيار — لنوع الإعلان أو اختيار المنشأة
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

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
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.white : AppColors.grey,
              ),
              const SizedBox(width: 6),
            ],
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

/// صندوق اختيار صورة الإعلان — معاينة أو زر إضافة، مع إمكانية الحذف
class _ImagePickerBox extends StatelessWidget {
  const _ImagePickerBox({
    required this.imageUrl,
    required this.uploading,
    required this.onTap,
    required this.onRemove,
  });

  final String imageUrl;
  final bool uploading;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryLight, width: 1.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (uploading)
              Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            else if (imageUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 30,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.adImageLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            if (imageUrl.isNotEmpty && onRemove != null)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Pressable(
                  onTap: onRemove,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
