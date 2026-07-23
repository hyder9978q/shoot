import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/shoot_logo.dart';
import 'account_type_screen.dart';

/// شاشة الاسم — تظهر مرة وحدة بعد أول تسجيل دخول
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _nameController = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _continue({required bool save}) async {
    final name = _nameController.text.trim();
    if (save && name.isNotEmpty) {
      setState(() => _saving = true);
      try {
        await UserService.instance.saveName(name);
      } catch (_) {
        // ما نوقف المستخدم على خطأ حفظ الاسم — نكمل ونحاول بعدين
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AccountTypeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _focus.hasFocus ? AppColors.primary : AppColors.border;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // رأس الهوية — تدرج أخضر بزوايا سفلية (زي باقي رؤوس التطبيق)
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
                    AppStrings.nameTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.nameSubtitle,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // خانة الاسم — نفس خانة رقم الهاتف بشاشة الدخول
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.subtleFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 22,
                          color: _focus.hasFocus
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            focusNode: _focus,
                            textInputAction: TextInputAction.done,
                            maxLength: InputSanitizer.nameMaxLength,
                            inputFormatters: [InputSanitizer.deny()],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                            ),
                            decoration: InputDecoration(
                              hintText: AppStrings.nameHint,
                              hintStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                              counterText: '',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _continue(save: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Pressable(
                    onTap: _saving ? null : () => _continue(save: true),
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _saving
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.primaryShadow,
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : const Text(
                              AppStrings.nameStart,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _saving ? null : () => _continue(save: false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                    ),
                    child: const Text(AppStrings.nameSkip),
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
