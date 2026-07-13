import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/core/theme/theme_controller.dart';
import 'package:shoot/features/home/widgets/play_now_section.dart';
import 'package:shoot/features/auth/screens/login_screen.dart';
import 'package:shoot/features/auth/screens/name_screen.dart';
import 'package:shoot/features/players/screens/new_request_screen.dart';
import 'package:shoot/features/bookings/screens/booking_success_screen.dart';
import 'package:shoot/features/fields/screens/field_details_screen.dart';
import 'package:shoot/features/game/screens/game_screen.dart';
import 'package:shoot/features/owner/screens/owner_dashboard_screen.dart';
import 'package:shoot/features/players/screens/players_tab.dart';
import 'package:shoot/features/shell/main_shell.dart';
import 'package:shoot/features/splash/splash_screen.dart';

/// لقطات شاشة للتصميم — تنحفظ بـ test/tools/screenshots/
///
/// التحديث:
///   flutter test test/tools/screenshots_test.dart --update-goldens
void main() {
  Widget app(Widget home) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: home,
    );
  }

  Future<void> shoot(
    WidgetTester tester,
    Widget home,
    String name, {
    // false = شاشات بيها مؤقتات (مثل السبلاش) ما ينفع وياها pumpAndSettle
    bool waitForSettle = true,
  }) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(home));
    if (waitForSettle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 600));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/$name.png'),
    );
  }

  testWidgets('شاشة البداية', (tester) async {
    await shoot(tester, const SplashScreen(), 'splash', waitForSettle: false);
    // نفرّغ مؤقت الانتقال حتى لا يفشل الاختبار
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('تسجيل الدخول', (tester) async {
    await shoot(tester, const LoginScreen(), 'login');
  });

  testWidgets('الرئيسية', (tester) async {
    PlayNowSection.debugNowHour = 20;
    addTearDown(() => PlayNowSection.debugNowHour = null);
    await shoot(tester, const MainShell(), 'home');
  });

  testWidgets('الرئيسية — الوضع الليلي', (tester) async {
    PlayNowSection.debugNowHour = 20;
    ThemeController.instance.setDark(true);
    addTearDown(() {
      PlayNowSection.debugNowHour = null;
      ThemeController.instance.setDark(false);
    });
    await shoot(tester, const MainShell(), 'home_dark');
  });

  testWidgets('تفاصيل الملعب — الوضع الليلي', (tester) async {
    ThemeController.instance.setDark(true);
    addTearDown(() => ThemeController.instance.setDark(false));
    final field = FieldsService.instance.search().first;
    await shoot(tester, FieldDetailsScreen(field: field), 'details_dark');
  });

  testWidgets('تفاصيل الملعب', (tester) async {
    final field = FieldsService.instance.search().first;
    await shoot(tester, FieldDetailsScreen(field: field), 'details');
  });

  testWidgets('ناقصنا لاعب', (tester) async {
    await shoot(
      tester,
      const Scaffold(body: PlayersTab()),
      'players',
    );
  });

  testWidgets('نشر إعلان لاعب', (tester) async {
    await shoot(tester, const NewRequestScreen(), 'new_request');
  });

  testWidgets('شاشة الاسم', (tester) async {
    await shoot(tester, const NameScreen(), 'name');
  });

  // ملاحظة: ماكو لقطة للخريطة — بلاطاتها تحتاج path_provider (مو متوفر
  // باختبارات الويدجت). التغطية الوظيفية موجودة بـ widget_test.dart.

  testWidgets('لعبة ضربات الترجيح', (tester) async {
    await shoot(tester, const GameScreen(), 'game');
  });

  testWidgets('لوحة صاحب الملعب', (tester) async {
    final field = FieldsService.instance.search().first;
    await shoot(
      tester,
      OwnerDashboardScreen(fields: [field]),
      'owner',
    );
  });

  testWidgets('نجاح الحجز', (tester) async {
    final field = FieldsService.instance.search().first;
    const slot = TimeSlot(hour: 17, isBooked: false);
    await shoot(
      tester,
      BookingSuccessScreen(field: field, slot: slot),
      'success',
    );
  });
}
