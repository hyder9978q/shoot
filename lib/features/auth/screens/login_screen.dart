import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart' show Sport;
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/field_visual.dart';
import '../../../core/widgets/pressable.dart';
import 'otp_screen.dart';

/// شاشة تسجيل الدخول برقم الموبايل (شاشة ٠٢ بالتصميم)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  String? _errorText;
  bool _sending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!AuthService.isValidIraqiPhone(phone)) {
      setState(() => _errorText = AppStrings.phoneError);
      return;
    }
    setState(() {
      _errorText = null;
      _sending = true;
    });
    try {
      await AuthService.instance.sendOtp(phone);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorText = switch (e.code) {
          'operation-not-allowed' => AppStrings.phoneAuthDisabled,
          'too-many-requests' => AppStrings.tooManyRequests,
          'invalid-phone-number' => AppStrings.phoneError,
          'billing-not-enabled' => AppStrings.realSmsNeedsBilling,
          _ => AppStrings.otpSendError,
        };
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorText = AppStrings.otpSendError;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // رأس بصورة الملعب مع تظليل أخضر — والتحية بأسفله
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const FieldVisual(sport: Sport.football),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF15803D).withValues(alpha: 0.35),
                        const Color(0xFF16A34A).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 28,
                  end: 28,
                  bottom: 26,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        AppStrings.loginTitle,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.loginSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.phoneLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PhoneField(
                    controller: _phoneController,
                    hasError: _errorText != null,
                    onSubmitted: (_) => _sendCode(),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Pressable(
                    onTap: _sending ? null : _sendCode,
                    child: Container(
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _sending
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.primaryShadow,
                      ),
                      child: _sending
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : const Text(
                              AppStrings.sendCode,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.termsNote,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      height: 1.7,
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

/// خانة رقم الهاتف — تعبئة رمادية + مفتاح الدولة بالطرف
class _PhoneField extends StatefulWidget {
  const _PhoneField({
    required this.controller,
    required this.hasError,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onSubmitted;

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = widget.hasError
        ? AppColors.error
        : _focus.hasFocus
            ? AppColors.primary
            : AppColors.border;

    return Container(
      height: 56,
      padding: const EdgeInsetsDirectional.only(start: 16),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            // الرقم يُكتب من اليسار لليمين حتى بالواجهة العربية
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.dark,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.phoneHint,
                  hintStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.muted,
                  ),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: widget.onSubmitted,
              ),
            ),
          ),
          // مفتاح الدولة بحافة فاصلة (زي التصميم)
          Container(
            height: 28,
            padding: const EdgeInsetsDirectional.only(start: 12, end: 16),
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: AppColors.border, width: 1.5),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '+964',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(width: 7),
                const Text('🇮🇶', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
