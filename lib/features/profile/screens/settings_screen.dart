import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/app_mode.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../splash/splash_screen.dart';

/// رقم واتساب الدعم — نفس رقم التجربة المستخدم بباقي بيانات التطبيق التجريبية
const String _supportPhone = '+9647701234567';

/// شاشة الإعدادات — الحساب، المظهر، الإشعارات، وعن التطبيق والدعم
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyBookingConfirm = true;
  bool _notifyReminder = true;
  bool _notifyPlayerRequests = true;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    UserService.instance.revision.addListener(_onUserChanged);
  }

  @override
  void dispose() {
    UserService.instance.revision.removeListener(_onUserChanged);
    super.dispose();
  }

  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPrefs() async {
    final confirm = await LocalStore.notifyBookingConfirm;
    final reminder = await LocalStore.notifyReminder;
    final requests = await LocalStore.notifyPlayerRequests;
    if (!mounted) return;
    setState(() {
      _notifyBookingConfirm = confirm;
      _notifyReminder = reminder;
      _notifyPlayerRequests = requests;
      _prefsLoaded = true;
    });
  }

  String get _phone {
    if (AppMode.isMock) return AppStrings.guestName;
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber ?? AppStrings.guestName;
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initialName: UserService.instance.name),
    );
    if (name == null || !mounted) return;
    await UserService.instance.saveName(name);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.nameSavedMsg)));
  }

  Future<void> _pickCity() async {
    final cities = FieldsService.instance.cities;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                AppStrings.chooseCityTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final city in cities)
                    ListTile(
                      title: Text(
                        city,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: UserService.instance.city == city
                          ? Icon(Icons.check_rounded, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(city),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await UserService.instance.saveCity(selected);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.citySavedMsg)));
  }

  Future<void> _changePhoto() async {
    try {
      await UserService.instance.pickAndUploadPhoto();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.photoSaved)));
    } on InvalidImageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.tooLarge ? AppStrings.photoTooLarge : AppStrings.photoInvalidType,
          ),
        ),
      );
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.photosNeedLiveApp)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.photoUploadError)),
      );
    }
  }

  Future<void> _contactSupport() async {
    final phone = _supportPhone.replaceAll('+', '');
    await launchUrl(
      Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(AppStrings.supportWhatsappMessage)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openLegalText(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _LegalTextScreen(title: title, body: body)),
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    // مع Firebase: حارس الجلسة بـ MainShell يلتقط الخروج ويوجّه لشاشة
    // الدخول تلقائياً — ما ننقل مرتين
    if (Firebase.apps.isNotEmpty) return;
    UserService.instance.resetForSignOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        children: [
          const _SectionHeader(AppStrings.settingsAccountSection),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                label: AppStrings.settingsNameLabel,
                value: UserService.instance.name.isEmpty
                    ? AppStrings.guestName
                    : UserService.instance.name,
                onTap: _editName,
              ),
              _SettingsRow(
                icon: Icons.location_on_outlined,
                label: AppStrings.settingsCityLabel,
                value: UserService.instance.city.isEmpty
                    ? AppStrings.pickCity
                    : UserService.instance.city,
                onTap: _pickCity,
              ),
              _SettingsRow(
                icon: Icons.camera_alt_outlined,
                label: AppStrings.settingsPhotoLabel,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AvatarThumb(
                      name: UserService.instance.name,
                      photoUrl: UserService.instance.photoUrl,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.border,
                      size: 22,
                    ),
                  ],
                ),
                onTap: _changePhoto,
              ),
              _SettingsRow(
                icon: Icons.call_outlined,
                label: AppStrings.settingsPhoneLabel,
                value: _phone,
                valueLtr: true,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeader(AppStrings.settingsAppearanceSection),
          _SettingsCard(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: ThemeController.instance.isDark,
                builder: (context, isDark, _) => _SettingsRow(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.dark_mode_outlined,
                  label: AppStrings.settingsDarkModeLabel,
                  hint: AppStrings.settingsDarkModeHint,
                  last: true,
                  trailing: Switch(
                    value: isDark,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => UserService.instance.saveThemeDark(v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeader(AppStrings.settingsNotificationsSection),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.event_available_outlined,
                label: AppStrings.notifyBookingConfirmLabel,
                hint: AppStrings.notifyBookingConfirmHint,
                trailing: Switch(
                  value: _notifyBookingConfirm,
                  activeThumbColor: AppColors.primary,
                  onChanged: !_prefsLoaded
                      ? null
                      : (v) {
                          setState(() => _notifyBookingConfirm = v);
                          LocalStore.setNotifyBookingConfirm(v);
                        },
                ),
              ),
              _SettingsRow(
                icon: Icons.alarm_outlined,
                label: AppStrings.notifyReminderLabel,
                hint: AppStrings.notifyReminderHint,
                trailing: Switch(
                  value: _notifyReminder,
                  activeThumbColor: AppColors.primary,
                  onChanged: !_prefsLoaded
                      ? null
                      : (v) {
                          setState(() => _notifyReminder = v);
                          LocalStore.setNotifyReminder(v);
                        },
                ),
              ),
              _SettingsRow(
                icon: Icons.group_add_outlined,
                label: AppStrings.notifyPlayerRequestsLabel,
                hint: AppStrings.notifyPlayerRequestsHint,
                last: true,
                trailing: Switch(
                  value: _notifyPlayerRequests,
                  activeThumbColor: AppColors.primary,
                  onChanged: !_prefsLoaded
                      ? null
                      : (v) {
                          setState(() => _notifyPlayerRequests = v);
                          LocalStore.setNotifyPlayerRequests(v);
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeader(AppStrings.settingsAboutSection),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.headset_mic_outlined,
                label: AppStrings.contactSupportLabel,
                hint: AppStrings.contactSupportHint,
                onTap: _contactSupport,
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: AppStrings.privacyPolicyLabel,
                onTap: () => _openLegalText(
                  AppStrings.privacyPolicyTitle,
                  AppStrings.privacyPolicyBody,
                ),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: AppStrings.termsOfUseLabel,
                onTap: () => _openLegalText(
                  AppStrings.termsOfUseTitle,
                  AppStrings.termsOfUseBody,
                ),
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                label: AppStrings.appVersionLabel,
                value: ArabicNum.convert(AppStrings.appVersionNumber),
                valueLtr: true,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                label: AppStrings.logout,
                danger: true,
                last: true,
                onTap: _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// حوار تعديل الاسم — StatefulWidget مستقل حتى يتحكّم controller بدورة
/// حياته بنفسه (ينحذف تلقائياً بالوقت الصحيح، حتى لو الحوار بعده يتحرك
/// بحركة الخروج وقت الإغلاق)
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppStrings.nameEmptyError);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.editNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: InputSanitizer.nameMaxLength,
        inputFormatters: [InputSanitizer.deny()],
        decoration: InputDecoration(
          hintText: AppStrings.nameHint,
          counterText: '',
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(onPressed: _save, child: const Text(AppStrings.save)),
      ],
    );
  }
}

/// عنوان قسم بسيط فوق كل بطاقة إعدادات
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

/// بطاقة تجمع صفوف قسم إعدادات وحدة
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(children: children),
    );
  }
}

/// صف بشاشة الإعدادات — أيقونة + عنوان (وتلميح اختياري) + قيمة/سهم/مفتاح
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.hint,
    this.value,
    this.valueLtr = false,
    this.trailing,
    this.onTap,
    this.last = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final String? value;
  final bool valueLtr;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color tileColor = danger ? AppColors.errorSoft : AppColors.primaryTint;
    final Color iconColor = danger ? AppColors.error : AppColors.primary;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: last
              ? null
              : BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.hairline)),
                ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: danger ? AppColors.error : AppColors.dark,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint!,
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
              if (trailing != null)
                trailing!
              else if (value != null) ...[
                Text(
                  value!,
                  textDirection: valueLtr ? TextDirection.ltr : null,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.border,
                    size: 20,
                  ),
                ],
              ] else if (onTap != null && !danger)
                Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.border,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// أفاتار صغير مصغّر — يبين بجانب صف "الصورة"
class _AvatarThumb extends StatelessWidget {
  const _AvatarThumb({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '؟' : name.characters.first;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        shape: BoxShape.circle,
      ),
      child: photoUrl.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            )
          : CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              width: 32,
              height: 32,
              errorWidget: (_, _, _) => Text(
                initial,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
    );
  }
}

/// شاشة نص ثابت — تُستخدم لعرض سياسة الخصوصية وشروط الاستخدام
class _LegalTextScreen extends StatelessWidget {
  const _LegalTextScreen({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Text(
          body.trim(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.dark,
            height: 1.9,
          ),
        ),
      ),
    );
  }
}
