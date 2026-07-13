import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/widgets/pressable.dart';
import '../../shell/main_shell.dart';
import 'name_screen.dart';

/// شاشة رمز التحقق (OTP) — 6 خانات مع عدّاد إعادة إرسال
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorText;
  bool _verifying = false;
  Timer? _resendTimer;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length < 6) {
      setState(() => _errorText = AppStrings.otpError);
      return;
    }
    setState(() {
      _errorText = null;
      _verifying = true;
    });
    final ok = await AuthService.instance.verifyOtp(_codeController.text);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (ok) {
      // نحمّل ملف المستخدم: إذا ما عنده اسم (أول مرة) نسأله
      await UserService.instance.load();
      if (!mounted) return;
      final firstTime = UserService.instance.name.isEmpty;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              firstTime ? const NameScreen() : const MainShell(),
        ),
        (route) => false,
      );
    } else {
      setState(() => _errorText = AppStrings.otpError);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    try {
      await AuthService.instance.sendOtp(widget.phone);
      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.codeSentAgain)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.otpSendError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _codeController.text;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // زر رجوع مربّع (زي التصميم)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Pressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.subtleFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: AppColors.dark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                AppStrings.otpTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.otpSubtitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 32),
              // 6 خانات للرمز فوق حقل إدخال مخفي
              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // الحقل الحقيقي (شفاف) — يستقبل الكتابة
                    Opacity(
                      opacity: 0,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _codeController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration:
                              const InputDecoration(counterText: ''),
                          onSubmitted: (_) => _verify(),
                        ),
                      ),
                    ),
                    // الخانات المعروضة
                    IgnorePointer(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 6; i++) ...[
                              if (i > 0) const SizedBox(width: 9),
                              Expanded(
                                child: _OtpBox(
                                  digit: i < code.length ? code[i] : '',
                                  active: i == code.length,
                                  hasError: _errorText != null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // ملاحظة التجربة — تنشال من نفعّل الرسائل الحقيقية
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  AppStrings.otpDevHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.dark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 22),
              // عدّاد إعادة الإرسال — نص وسط زي التصميم
              Center(
                child: _resendSeconds > 0
                    ? Text.rich(
                        TextSpan(
                          text: '${AppStrings.resendIn} ',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                          children: [
                            TextSpan(
                              text: ArabicNum.count(_resendSeconds),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Pressable(
                        onTap: _resend,
                        child: Text(
                          AppStrings.resendCode,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 28),
              Pressable(
                onTap: _verifying ? null : _verify,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _verifying
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.primaryShadow,
                  ),
                  child: _verifying
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          AppStrings.confirm,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// خانة رمز — فاضية (رمادية)، مكتوبة (خضراء فاتحة)، نشطة (حد أخضر)
class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      height: 66,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasError
            ? AppColors.errorSoft
            : filled
                ? AppColors.primaryTint
                : active
                    ? AppColors.surface
                    : AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError
              ? AppColors.error
              : filled || active
                  ? AppColors.primary
                  : AppColors.border,
          width: 2,
        ),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: AppColors.dark,
        ),
      ),
    );
  }
}
