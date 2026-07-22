import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/time_labels.dart';
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/pressable.dart';
import 'field_photos_screen.dart';

/// شاشة إدارة الملعب — تحكم كامل لصاحب الملعب بملعبه هو فقط:
/// المعلومات الأساسية، الوسائط (صور/روابط/لقطات)، وطرق الدفع.
class FieldManageScreen extends StatefulWidget {
  const FieldManageScreen({super.key, required this.field, this.onChanged});

  final Field field;

  /// ينستدعى بعد أي تغيير حتى الشاشة السابقة تحدّث بياناتها
  final ValueChanged<Field>? onChanged;

  @override
  State<FieldManageScreen> createState() => _FieldManageScreenState();
}

class _FieldManageScreenState extends State<FieldManageScreen> {
  late Field _field = widget.field;
  bool _busy = false;

  // -------- المعلومات الأساسية --------
  late final TextEditingController _nameController = TextEditingController(
    text: _field.name,
  );
  late final TextEditingController _areaController = TextEditingController(
    text: _field.area,
  );
  late final TextEditingController _cityController = TextEditingController(
    text: _field.city,
  );
  late final TextEditingController _priceController = TextEditingController(
    text: '${_field.pricePerHour}',
  );
  late Sport _sport = _field.sport;
  late int _openHour = _field.openHour;
  late int _closeHour = _field.closeHour;
  late bool _isOpen = _field.isOpen;

  // -------- الوسائط --------
  late final TextEditingController _mapsController = TextEditingController(
    text: _field.mapsUrl,
  );

  // -------- طرق الدفع --------
  late bool _payDeposit = _field.paymentDeposit;
  late bool _payCash = _field.paymentCashOnArrival;
  late bool _zainCash = _field.zainCashEnabled;
  late final TextEditingController _merchantController = TextEditingController(
    text: _field.zainCashMerchantId,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _priceController.dispose();
    _mapsController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _applyUpdate(Field updated) {
    setState(() => _field = updated);
    widget.onChanged?.call(updated);
  }

  /// ينفّذ عملية حفظ ويتكفل بحالة الانشغال ورسائل الخطأ.
  /// [onInvalid] لرسالة إدخال غلط بدل رسالة الشبكة العامة.
  Future<void> _run(
    Future<Field> Function() action, {
    required String successMessage,
    String? invalidMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _applyUpdate(await action());
      _snack(successMessage);
    } on ArgumentError {
      _snack(invalidMessage ?? AppStrings.infoSaveError);
    } on InvalidImageException catch (e) {
      _snack(
        e.tooLarge ? AppStrings.photoTooLarge : AppStrings.photoInvalidType,
      );
    } on StateError {
      _snack(AppStrings.photosNeedLiveApp);
    } catch (_) {
      _snack(AppStrings.infoSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- المعلومات الأساسية ----------

  Future<void> _saveInfo() async {
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
    if (price == null || price < 0 || price > 1000000) {
      _snack(AppStrings.priceError);
      return;
    }
    if (_openHour >= _closeHour) {
      _snack(AppStrings.hoursError);
      return;
    }
    await _run(
      () => FieldsService.instance.updateFieldInfo(
        _field,
        name: _nameController.text,
        area: _areaController.text,
        city: _cityController.text,
        sport: _sport,
        pricePerHour: price,
        openHour: _openHour,
        closeHour: _closeHour,
        isOpen: _isOpen,
      ),
      successMessage: AppStrings.infoSaved,
    );
  }

  // ---------- الوسائط ----------

  Future<void> _saveMapsUrl() async {
    await _run(
      () => FieldsService.instance.setMapsUrl(_field, _mapsController.text),
      successMessage: AppStrings.mapsLinkSaved,
      invalidMessage: AppStrings.mapsLinkError,
    );
  }

  Future<List<XFile>> _pickImages() async {
    if (!FieldsService.canUploadPhotos) {
      _snack(AppStrings.photosNeedLiveApp);
      return const [];
    }
    return ImagePicker().pickMultiImage(imageQuality: 75);
  }

  Future<void> _addPromoPhotos() async {
    final picked = await _pickImages();
    if (picked.isEmpty || !mounted) return;
    await _run(
      () => FieldsService.instance.addPromoPhotos(_field, picked),
      successMessage: AppStrings.photoUploadedOk,
    );
  }

  Future<void> _addHighlightPhotos() async {
    final picked = await _pickImages();
    if (picked.isEmpty || !mounted) return;
    await _run(
      () => FieldsService.instance.addHighlightPhotos(_field, picked),
      successMessage: AppStrings.highlightAdded,
    );
  }

  Future<void> _addHighlightVideo() async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.videoLinkTitle),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: AppStrings.videoLinkHint,
            hintTextDirection: TextDirection.ltr,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    await _run(
      () => FieldsService.instance.addHighlightVideo(_field, controller.text),
      successMessage: AppStrings.highlightAdded,
      invalidMessage: AppStrings.videoLinkError,
    );
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
    return confirmed == true && mounted;
  }

  Future<void> _deletePromoPhoto(String url) async {
    if (!await _confirmDelete(
      AppStrings.deletePhotoTitle,
      AppStrings.deletePhotoConfirm,
    )) {
      return;
    }
    await _run(
      () => FieldsService.instance.removePromoPhoto(_field, url),
      successMessage: AppStrings.photoDeleted,
    );
  }

  Future<void> _deleteHighlight(FieldHighlight highlight) async {
    if (!await _confirmDelete(
      AppStrings.deleteHighlightTitle,
      AppStrings.deleteHighlightConfirm,
    )) {
      return;
    }
    await _run(
      () => FieldsService.instance.removeHighlight(_field, highlight),
      successMessage: AppStrings.photoDeleted,
    );
  }

  // ---------- الخدمات (مراكز العلاج خصوصاً) ----------

  bool get _showServices =>
      _field.sport == Sport.therapy ||
      _sport == Sport.therapy ||
      _field.services.isNotEmpty;

  Future<void> _addService() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.addServiceButton),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              maxLength: 60,
              inputFormatters: [InputSanitizer.deny()],
              decoration: const InputDecoration(
                hintText: AppStrings.serviceNameHint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              maxLength: 7,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: AppStrings.servicePriceLabel,
                counterText: '',
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;

    if (nameController.text.trim().isEmpty) {
      _snack(AppStrings.serviceNameError);
      return;
    }
    final price = int.tryParse(priceController.text.trim());
    if (price == null || price < 0 || price > 1000000) {
      _snack(AppStrings.priceError);
      return;
    }
    await _run(
      () => FieldsService.instance.updateServices(_field, [
        ..._field.services,
        VenueService(name: nameController.text, price: price),
      ]),
      successMessage: AppStrings.serviceAdded,
    );
  }

  Future<void> _deleteService(VenueService service) async {
    if (!await _confirmDelete(
      AppStrings.deleteServiceTitle,
      AppStrings.deleteServiceConfirm,
    )) {
      return;
    }
    await _run(
      () => FieldsService.instance.updateServices(_field, [
        for (final s in _field.services)
          if (s != service) s,
      ]),
      successMessage: AppStrings.serviceDeleted,
    );
  }

  // ---------- طرق الدفع ----------

  Future<void> _savePayments() async {
    if (!_payDeposit && !_payCash) {
      _snack(AppStrings.onePaymentRequired);
      return;
    }
    if (_zainCash && _merchantController.text.trim().isEmpty) {
      _snack(AppStrings.merchantIdError);
      return;
    }
    await _run(
      () => FieldsService.instance.updatePaymentMethods(
        _field,
        deposit: _payDeposit,
        cashOnArrival: _payCash,
        zainCashEnabled: _zainCash,
        zainCashMerchantId: _merchantController.text,
      ),
      successMessage: AppStrings.paymentsSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${AppStrings.manageFieldTitle} · ${_field.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
          children: [
            _buildInfoCard(),
            const SizedBox(height: 18),
            _buildMediaCard(),
            // الخدمات — لمراكز العلاج (أو أي منشأة عندها خدمات)
            if (_showServices) ...[
              const SizedBox(height: 18),
              _buildServicesCard(),
            ],
            const SizedBox(height: 18),
            _buildPaymentsCard(),
          ],
        ),
      ),
    );
  }

  // ---------- بطاقة المعلومات الأساسية ----------

  Widget _buildInfoCard() {
    return _SectionCard(
      icon: Icons.tune_rounded,
      title: AppStrings.basicInfoSection,
      children: [
        _FieldLabel(AppStrings.fieldNameLabel),
        TextField(
          controller: _nameController,
          maxLength: 50,
          inputFormatters: [InputSanitizer.deny()],
          decoration: const InputDecoration(counterText: ''),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(AppStrings.areaLabel),
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
                  _FieldLabel(AppStrings.cityLabel),
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
        const SizedBox(height: 14),
        _FieldLabel(AppStrings.priceLabel),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          maxLength: 7,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: ''),
        ),
        const SizedBox(height: 14),
        _FieldLabel(AppStrings.sportTypeLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sport in Sport.values)
              _ChoicePill(
                label: sport.label,
                icon: sport.icon,
                selected: _sport == sport,
                onTap: () => setState(() => _sport = sport),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _FieldLabel(AppStrings.workingHoursLabel),
        Row(
          children: [
            Expanded(
              child: _HourDropdown(
                label: AppStrings.opensAtLabel,
                value: _openHour,
                min: 0,
                max: 23,
                onChanged: (v) => setState(() => _openHour = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HourDropdown(
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
        _FieldLabel(AppStrings.fieldStatusLabel),
        Pressable(
          onTap: () => setState(() => _isOpen = !_isOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _isOpen ? AppColors.primaryTint : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isOpen ? AppColors.primaryLight : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isOpen
                      ? Icons.check_circle_rounded
                      : Icons.pause_circle_outline_rounded,
                  size: 20,
                  color: _isOpen ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isOpen
                        ? AppStrings.fieldOpenLabel
                        : AppStrings.fieldClosedLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isOpen ? AppColors.primaryDark : AppColors.grey,
                    ),
                  ),
                ),
                Switch(
                  value: _isOpen,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isOpen = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _saveInfo,
            child: const Text(AppStrings.saveInfoButton),
          ),
        ),
      ],
    );
  }

  // ---------- بطاقة الوسائط ----------

  Widget _buildMediaCard() {
    return _SectionCard(
      icon: Icons.perm_media_rounded,
      title: AppStrings.mediaSection,
      children: [
        // صور الملعب — شاشة مستقلة (رفع/حذف/ترتيب)
        Pressable(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    FieldPhotosScreen(field: _field, onChanged: _applyUpdate),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.photo_library_rounded,
                  size: 22,
                  color: AppColors.primaryDeep,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.fieldPhotosTitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: AppColors.muted,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // رابط الموقع على خرائط Google
        _FieldLabel(AppStrings.mapsLinkLabel),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _mapsController,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: AppStrings.mapsLinkHint,
                  hintTextDirection: TextDirection.ltr,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _saveMapsUrl,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Icon(Icons.check_rounded, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // الصور الترويجية (بانر صفحة الملعب)
        _FieldLabel(AppStrings.promoSection),
        Text(
          AppStrings.promoHint,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        _MediaThumbRow(
          sport: _field.sport,
          items: [
            for (final url in _field.promoImageUrls)
              _MediaThumb(url: url, onDelete: () => _deletePromoPhoto(url)),
          ],
          onAdd: _busy ? null : _addPromoPhotos,
          addLabel: AppStrings.addPromoButton,
        ),
        const SizedBox(height: 18),
        // لقطات الملعب (هايلايتس)
        _FieldLabel(AppStrings.highlightsSection),
        Text(
          AppStrings.highlightsHint,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        _MediaThumbRow(
          sport: _field.sport,
          items: [
            for (final highlight in _field.highlights)
              _MediaThumb(
                url: highlight.isVideo ? '' : highlight.url,
                isVideo: highlight.isVideo,
                onDelete: () => _deleteHighlight(highlight),
              ),
          ],
          onAdd: _busy ? null : _addHighlightPhotos,
          addLabel: AppStrings.addHighlightPhoto,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _addHighlightVideo,
            icon: const Icon(Icons.video_library_rounded, size: 20),
            label: const Text(AppStrings.addHighlightVideo),
          ),
        ),
      ],
    );
  }

  // ---------- بطاقة الخدمات ----------

  Widget _buildServicesCard() {
    return _SectionCard(
      icon: Icons.medical_services_rounded,
      title: AppStrings.manageServicesSection,
      children: [
        Text(
          AppStrings.manageServicesHint,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        if (_field.services.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              AppStrings.noServicesYet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
                height: 1.6,
              ),
            ),
          )
        else
          for (final service in _field.services)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      service.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  Text(
                    '${ArabicNum.money(service.price)} ${AppStrings.iqd}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Pressable(
                    onTap: _busy ? null : () => _deleteService(service),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _addService,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(AppStrings.addServiceButton),
          ),
        ),
      ],
    );
  }

  // ---------- بطاقة طرق الدفع ----------

  Widget _buildPaymentsCard() {
    return _SectionCard(
      icon: Icons.payments_rounded,
      title: AppStrings.paymentsSection,
      children: [
        Text(
          AppStrings.paymentsHint,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _PaymentToggle(
          icon: Icons.account_balance_wallet_rounded,
          title: AppStrings.payDepositOption,
          subtitle: AppStrings.payDepositDesc,
          value: _payDeposit,
          onChanged: (v) => setState(() => _payDeposit = v),
        ),
        const SizedBox(height: 10),
        _PaymentToggle(
          icon: Icons.money_rounded,
          title: AppStrings.payCashOption,
          subtitle: AppStrings.payCashDesc,
          value: _payCash,
          onChanged: (v) => setState(() => _payCash = v),
        ),
        const SizedBox(height: 16),
        // زين كاش — واجهة فقط، التفعيل الفعلي placeholder
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 22,
                    color: AppColors.primaryDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.zainCashSection,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      AppStrings.comingSoon,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  Switch(
                    value: _zainCash,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _zainCash = v),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.zainCashComingSoon,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  height: 1.6,
                ),
              ),
              if (_zainCash) ...[
                const SizedBox(height: 12),
                _FieldLabel(AppStrings.merchantIdLabel),
                TextField(
                  controller: _merchantController,
                  maxLength: 50,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [InputSanitizer.deny()],
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: AppStrings.merchantIdHint,
                    hintTextDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _savePayments,
            child: const Text(AppStrings.saveInfoButton),
          ),
        ),
      ],
    );
  }
}

/// بطاقة قسم — عنوان بأيقونة + محتوى
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// تسمية فوق حقل إدخال
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

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

/// كبسولة اختيار (نوع الرياضة)
class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
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

/// قائمة اختيار ساعة (00:00 لـ 24:00)
class _HourDropdown extends StatelessWidget {
  const _HourDropdown({
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
        _FieldLabel(label),
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

/// عنصر وسائط مصغّر — صورة أو بطاقة فيديو، مع زر حذف
class _MediaThumb {
  const _MediaThumb({
    required this.url,
    required this.onDelete,
    this.isVideo = false,
  });

  final String url;
  final bool isVideo;
  final VoidCallback onDelete;
}

/// صف مصغّرات أفقي + زر إضافة
class _MediaThumbRow extends StatelessWidget {
  const _MediaThumbRow({
    required this.sport,
    required this.items,
    required this.onAdd,
    required this.addLabel,
  });

  final Sport sport;
  final List<_MediaThumb> items;
  final VoidCallback? onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // زر الإضافة أول شي (أقرب للمستخدم بالـ RTL)
          Pressable(
            onTap: onAdd,
            child: Container(
              width: 96,
              margin: const EdgeInsetsDirectional.only(end: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 26,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      addLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final item in items)
            Container(
              width: 96,
              margin: const EdgeInsetsDirectional.only(end: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.isVideo)
                      Container(
                        color: AppColors.inkFixed,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.videoBadge,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      FieldPhoto(sport: sport, url: item.url),
                    PositionedDirectional(
                      top: 5,
                      end: 5,
                      child: Pressable(
                        onTap: item.onDelete,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// مفتاح طريقة دفع — أيقونة + عنوان + وصف + Switch
class _PaymentToggle extends StatelessWidget {
  const _PaymentToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value ? AppColors.primaryTint : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? AppColors.primaryLight : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: value ? AppColors.primaryDeep : AppColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
