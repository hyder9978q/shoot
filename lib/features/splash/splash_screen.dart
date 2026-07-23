import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/local_store.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/shoot_logo.dart';
import '../auth/screens/login_screen.dart';
import '../auth/screens/name_screen.dart';
import '../owner/screens/owner_shell.dart';
import '../shell/main_shell.dart';

/// شاشة البداية — هوية غارقة بالأخضر مع دخول ناعم
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
    _scale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), _goNext);
  }

  /// بوابة الجلسة: مسجّل دخول → التطبيق، غير مسجّل → شاشة الدخول فقط
  Future<void> _goNext() async {
    if (!mounted) return;

    final hasFirebase = Firebase.apps.isNotEmpty;
    var user = hasFirebase ? FirebaseAuth.instance.currentUser : null;
    if (hasFirebase && user == null) {
      // بعد التحديث (خصوصاً على الويب) استرجاع الجلسة ياخذ لحظة —
      // ننتظر أول إشعار حالة بدل ما نحكم من currentUser الفوري
      try {
        user = await FirebaseAuth.instance
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // ما وصل إشعار بالوقت المحدد — نكمل بالجلسة المحلية
      }
    }
    // الجلسة المحلية تغطي الدخول التجريبي (رمز 123456) بدون مستخدم Firebase
    final signedIn = user != null || await LocalStore.signedIn;
    if (!mounted) return;

    Widget next = const LoginScreen();
    if (signedIn) {
      // جلسة سارية: نحمّل الملف ونفوّته — إذا ما كمّل اسمه نسأله.
      // بعدها: صاحب المنشأة (باختياره أو تلقائياً لو يملك منشآت) يروح
      // لحسابه المنفصل الكامل، مو واجهة اللاعب.
      await UserService.instance.load();
      if (!mounted) return;
      next = UserService.instance.name.isEmpty
          ? const NameScreen()
          : UserService.instance.isOwner
          ? const OwnerShell()
          : const MainShell();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // تدرج شعاعي من مركز أعلى الشاشة (زي التصميم)
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.36),
            radius: 1.1,
            colors: [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF15803D)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: Stack(
          children: [
            // أشرطة قص العشب — خطوط عمودية خفيفة
            const Positioned.fill(
              child: CustomPaint(painter: _PitchStripesPainter()),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 44,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: ShootMark(size: 84, showTrail: true),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.slogan,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // سطر النسخة أسفل الشاشة
            PositionedDirectional(
              bottom: 44,
              start: 0,
              end: 0,
              child: Text(
                AppStrings.versionLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// أشرطة قص العشب — خطوط عمودية بيضاء شفافة كل ٤٤ بكسل
class _PitchStripesPainter extends CustomPainter {
  const _PitchStripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.white.withValues(alpha: 0.12);
    for (var x = 44.0; x < size.width; x += 45) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PitchStripesPainter oldDelegate) => false;
}
