import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/pressable.dart';

/// شاشة إدارة صور الملعب — صاحب الملعب يرفع عدة صور ويحذف اللي ما يريده.
/// أول صورة تصير غلاف الملعب بكل مكان بالتطبيق.
class FieldPhotosScreen extends StatefulWidget {
  const FieldPhotosScreen({super.key, required this.field, this.onChanged});

  final Field field;

  /// ينستدعى بعد أي تغيير حتى الشاشة السابقة تحدّث صورة الملعب
  final ValueChanged<Field>? onChanged;

  @override
  State<FieldPhotosScreen> createState() => _FieldPhotosScreenState();
}

class _FieldPhotosScreenState extends State<FieldPhotosScreen> {
  late Field _field = widget.field;
  bool _busy = false;

  Future<void> _addPhotos() async {
    if (!FieldsService.canUploadPhotos) {
      _snack(AppStrings.photosNeedLiveApp);
      return;
    }

    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 75);
    if (picked.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated =
          await FieldsService.instance.addFieldPhotos(_field, picked);
      if (!mounted) return;
      setState(() => _field = updated);
      widget.onChanged?.call(updated);
      _snack(AppStrings.photoUploadedOk);
    } on InvalidImageException catch (e) {
      // ملف مرفوض: نوضّح السبب (مو صورة / حجم كبير) بدل رسالة عامة
      if (mounted) {
        _snack(e.tooLarge
            ? AppStrings.photoTooLarge
            : AppStrings.photoInvalidType);
      }
    } catch (_) {
      if (mounted) _snack(AppStrings.photoUploadError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePhoto(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deletePhotoTitle),
        content: const Text(AppStrings.deletePhotoConfirm),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.yesDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated =
          await FieldsService.instance.removeFieldPhoto(_field, url);
      if (!mounted) return;
      setState(() => _field = updated);
      widget.onChanged?.call(updated);
      _snack(AppStrings.photoDeleted);
    } catch (_) {
      if (mounted) _snack(AppStrings.photoDeleteError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = _field.imageUrls;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${AppStrings.fieldPhotosTitle} · ${_field.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _addPhotos,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded, size: 22),
              label: Text(
                _busy ? AppStrings.uploadingPhotos : AppStrings.addPhotosButton,
              ),
            ),
          ),
        ),
      ),
      body: photos.isEmpty
          ? _EmptyPhotos(busy: _busy)
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              children: [
                Text(
                  '${ArabicNum.count(photos.length)} ${AppStrings.photosCountLabel}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                for (final (i, url) in photos.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PhotoTile(
                      sport: _field.sport,
                      url: url,
                      isCover: i == 0,
                      onDelete: _busy ? null : () => _deletePhoto(url),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// بطاقة صورة وحدة — الصورة + شارة الغلاف + زر حذف
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.sport,
    required this.url,
    required this.isCover,
    required this.onDelete,
  });

  final Sport sport;
  final String url;
  final bool isCover;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: FieldPhoto(sport: sport, url: url, borderRadius: radius),
          ),
          if (isCover)
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  AppStrings.coverPhotoBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: Pressable(
              onTap: onDelete,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة فارغة — ما بيه صور بعد
class _EmptyPhotos extends StatelessWidget {
  const _EmptyPhotos({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.noFieldPhotosTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.noFieldPhotosMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
