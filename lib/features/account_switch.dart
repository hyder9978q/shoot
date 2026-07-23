import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/services/user_service.dart';
import '../core/theme/app_colors.dart';
import 'owner/screens/owner_shell.dart';
import 'shell/main_shell.dart';

/// تبديل نوع الحساب (لاعب ↔ صاحب منشأة) — يستخدمها إعدادات الحسابين.
/// تأكيد واضح قبل التنفيذ، وما يفقد أي بيانات: منشآت المالك وحجوزات/
/// تقييمات اللاعب تبقى محفوظة بالكامل بغض النظر عن نوع الحساب الحالي،
/// لأنها كلها مرتبطة بمعرّف المستخدم نفسه مو بنوع حسابه.
Future<void> switchAccountType(
  BuildContext context, {
  required bool toOwner,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        toOwner
            ? AppStrings.switchToOwnerConfirmTitle
            : AppStrings.switchToPlayerConfirmTitle,
      ),
      content: Text(
        toOwner
            ? AppStrings.switchToOwnerConfirmBody
            : AppStrings.switchToPlayerConfirmBody,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.dark.withValues(alpha: 0.8),
          height: 1.7,
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.switchAccountCancelAction),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(AppStrings.switchAccountConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await UserService.instance.saveAccountType(toOwner ? 'owner' : 'player');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => toOwner ? const OwnerShell() : const MainShell(),
      ),
      (route) => false,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.switchAccountError)),
    );
  }
}
