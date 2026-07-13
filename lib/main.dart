import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // إذا فشل الاتصال بـ Firebase، التطبيق يكمل بالوضع التجريبي
  }
  runApp(const ShootApp());
}

class ShootApp extends StatelessWidget {
  const ShootApp({super.key});

  @override
  Widget build(BuildContext context) {
    // تبديل الوضع الليلي يعيد بناء التطبيق كله بمفتاح جديد
    // حتى كل الألوان (getters) تنقرأ من اللوحة الجديدة
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance.isDark,
      builder: (context, isDark, _) => MaterialApp(
        key: ValueKey(isDark),
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // اللغة العربية + الكتابة من اليمين لليسار
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
