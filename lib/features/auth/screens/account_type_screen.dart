import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/shoot_logo.dart';
import '../../owner/screens/owner_shell.dart';
import '../../shell/main_shell.dart';

/// شاشة اختيار نوع الحساب — تظهر مرة وحدة بعد أول تسجيل دخول (بعد شاشة
/// الاسم): لاعب يبقى بتجربته المعتادة، وصاحب منشأة ينتقل لحساب منفصل
/// كامل (لوحة تحكم، منشآتي، إعدادات خاصة) بدل واجهة اللاعب.
class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  bool _saving = false;

  Future<void> _choose(String type) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await UserService.instance.saveAccountType(type);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              type == 'owner' ? const OwnerShell() : const MainShell(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.accountTypeError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const ShootMark(size: 64, showTrail: true),
                  const SizedBox(height: 18),
                  const Text(
                    AppStrings.accountTypeTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.accountTypeSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white.withValues(alpha: 0.92),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AbsorbPointer(
              absorbing: _saving,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                children: [
                  _AccountTypeCard(
                    icon: Icons.sports_soccer_rounded,
                    title: AppStrings.accountTypePlayerTitle,
                    description: AppStrings.accountTypePlayerDesc,
                    onTap: () => _choose('player'),
                  ),
                  const SizedBox(height: 16),
                  _AccountTypeCard(
                    icon: Icons.storefront_rounded,
                    title: AppStrings.accountTypeOwnerTitle,
                    description: AppStrings.accountTypeOwnerDesc,
                    onTap: () => _choose('owner'),
                    accent: true,
                  ),
                  if (_saving) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة اختيار كبيرة — نوع الحساب مع أيقونة ووصف
class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent ? AppColors.accent : AppColors.border,
            width: accent ? 2 : 1.5,
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent ? AppColors.accentSoft : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 26,
                color: accent ? AppColors.accentInk : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: AppColors.border,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
