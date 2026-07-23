import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/app_mode.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/widgets/field_image.dart';
import '../../account_switch.dart';
import '../../profile/screens/settings_screen.dart';
import '../../splash/splash_screen.dart';
import 'field_manage_screen.dart';

/// إعدادات صاحب المنشأة — منشآته (اختصار لإدارة كل وحدة)، حسابه
/// الشخصي، المظهر، الدعم، وتسجيل الخروج. تعيد استخدام نفس صفوف/بطاقات
/// شاشة إعدادات اللاعب حتى يبقى المظهر موحّد بكل التطبيق.
class OwnerSettingsScreen extends StatefulWidget {
  const OwnerSettingsScreen({
    super.key,
    required this.fields,
    required this.onFieldsChanged,
  });

  final List<Field> fields;

  /// ينستدعى بعد أي تعديل بمنشأة — تبويب "منشآتي" يحدّث نفسه
  final VoidCallback onFieldsChanged;

  @override
  State<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends State<OwnerSettingsScreen> {
  @override
  void initState() {
    super.initState();
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

  String get _phone {
    if (AppMode.isMock) return AppStrings.guestName;
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber ?? AppStrings.guestName;
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => EditNameDialog(initialName: UserService.instance.name),
    );
    if (name == null || !mounted) return;
    await UserService.instance.saveName(name);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.nameSavedMsg)));
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
    final phone = supportWhatsappPhone.replaceAll('+', '');
    await launchUrl(
      Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(AppStrings.supportWhatsappMessage)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openLegalText(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalTextScreen(title: title, body: body)),
    );
  }

  void _manageField(Field field) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FieldManageScreen(
          field: field,
          onChanged: (_) => widget.onFieldsChanged(),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
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
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance.isDark,
      builder: (context, _, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.settingsTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        children: [
          SettingsSectionHeader(AppStrings.ownerSettingsVenuesSection),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              AppStrings.ownerSettingsVenuesHint,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
          ),
          if (widget.fields.isEmpty)
            SettingsCard(
              children: [
                SettingsRow(
                  icon: Icons.storefront_outlined,
                  label: AppStrings.noVenuesTitle,
                  last: true,
                ),
              ],
            )
          else
            SettingsCard(
              children: [
                for (final (i, field) in widget.fields.indexed)
                  _VenueRow(
                    field: field,
                    last: i == widget.fields.length - 1,
                    onTap: () => _manageField(field),
                  ),
              ],
            ),
          const SizedBox(height: 22),
          const SettingsSectionHeader(AppStrings.settingsAccountSection),
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.person_outline_rounded,
                label: AppStrings.settingsNameLabel,
                value: UserService.instance.name.isEmpty
                    ? AppStrings.guestName
                    : UserService.instance.name,
                onTap: _editName,
              ),
              SettingsRow(
                icon: Icons.camera_alt_outlined,
                label: AppStrings.settingsPhotoLabel,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsAvatarThumb(
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
              SettingsRow(
                icon: Icons.call_outlined,
                label: AppStrings.settingsPhoneLabel,
                hint: AppStrings.personalPhoneHint,
                value: _phone,
                valueLtr: true,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SettingsSectionHeader(AppStrings.settingsAppearanceSection),
          SettingsCard(
            children: [
              SettingsRow(
                icon: ThemeController.instance.isDark.value
                    ? Icons.dark_mode_rounded
                    : Icons.dark_mode_outlined,
                label: AppStrings.settingsDarkModeLabel,
                hint: AppStrings.settingsDarkModeHint,
                last: true,
                trailing: Switch(
                  value: ThemeController.instance.isDark.value,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => UserService.instance.saveThemeDark(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SettingsSectionHeader(AppStrings.switchAccountSection),
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.sports_soccer_rounded,
                label: AppStrings.switchToPlayerLabel,
                hint: AppStrings.switchToPlayerHint,
                last: true,
                onTap: () => switchAccountType(context, toOwner: false),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SettingsSectionHeader(AppStrings.settingsAboutSection),
          SettingsCard(
            children: [
              SettingsRow(
                icon: Icons.headset_mic_outlined,
                label: AppStrings.contactSupportLabel,
                hint: AppStrings.contactSupportHint,
                onTap: _contactSupport,
              ),
              SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: AppStrings.privacyPolicyLabel,
                onTap: () => _openLegalText(
                  AppStrings.privacyPolicyTitle,
                  AppStrings.privacyPolicyBody,
                ),
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                label: AppStrings.termsOfUseLabel,
                onTap: () => _openLegalText(
                  AppStrings.termsOfUseTitle,
                  AppStrings.termsOfUseBody,
                ),
              ),
              SettingsRow(
                icon: Icons.info_outline_rounded,
                label: AppStrings.appVersionLabel,
                value: ArabicNum.convert(AppStrings.appVersionNumber),
                valueLtr: true,
                last: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          SettingsCard(
            children: [
              SettingsRow(
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

/// صف منشأة داخل بطاقة "منشآتي" بالإعدادات — صورة مصغّرة + اسم + سعر
class _VenueRow extends StatelessWidget {
  const _VenueRow({
    required this.field,
    required this.last,
    required this.onTap,
  });

  final Field field;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: last
              ? null
              : BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.hairline)),
                ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: FieldImage(field: field),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      '${ArabicNum.money(field.pricePerHour)} ${AppStrings.perHourShort}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: AppColors.border,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
