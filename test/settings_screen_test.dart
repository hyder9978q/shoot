import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/constants/app_strings.dart';
import 'package:shoot/core/services/user_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/core/theme/theme_controller.dart';
import 'package:shoot/features/profile/screens/settings_screen.dart';
import 'package:shoot/features/splash/splash_screen.dart';

/// شاشة الإعدادات — تعديل الحساب، الوضع الليلي، تفضيلات الإشعارات،
/// وتسجيل الخروج الفعلي.
void main() {
  Widget app() => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: const SettingsScreen(),
  );

  setUp(() {
    UserService.instance.resetForSignOut();
  });

  tearDown(() {
    UserService.instance.resetForSignOut();
    ThemeController.instance.setDark(false);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  group('عرض الشاشة', () {
    testWidgets('تعرض الأقسام الأساسية واسم المستخدم الحالي', (
      tester,
    ) async {
      await UserService.instance.saveName('حيدر');
      await pumpSettings(tester);

      expect(find.text(AppStrings.settingsAccountSection), findsOneWidget);
      expect(find.text(AppStrings.settingsAppearanceSection), findsOneWidget);
      expect(
        find.text(AppStrings.settingsNotificationsSection),
        findsOneWidget,
      );
      expect(find.text(AppStrings.settingsAboutSection), findsOneWidget);
      expect(find.text('حيدر'), findsOneWidget);
    });
  });

  group('المظهر', () {
    testWidgets('تبديل الوضع الليلي من الإعدادات يفعّله فعلياً', (
      tester,
    ) async {
      expect(ThemeController.instance.isDark.value, isFalse);
      await pumpSettings(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(ThemeController.instance.isDark.value, isTrue);
    });
  });

  group('الإشعارات', () {
    testWidgets('تبدي كل المفاتيح مفعّلة، وتبديل مفتاح ينعكس بالواجهة', (
      tester,
    ) async {
      await pumpSettings(tester);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // أول مفتاح هو الوضع الليلي، الثلاثة الباقية إشعارات — كلها تبدي مفعّلة
      expect(switches.length, 4);
      for (final s in switches.skip(1)) {
        expect(s.value, isTrue);
      }

      // نبدّل أول مفتاح إشعار (تأكيد الحجز)
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();

      final updated = tester.widget<Switch>(find.byType(Switch).at(1));
      expect(updated.value, isFalse);
    });
  });

  group('تعديل الاسم', () {
    testWidgets('يحفظ الاسم الجديد بـ UserService', (tester) async {
      await UserService.instance.saveName('حيدر');
      await pumpSettings(tester);

      await tester.tap(find.text(AppStrings.settingsNameLabel));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.editNameTitle), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'أحمد');
      await tester.tap(find.text(AppStrings.save));
      await tester.pumpAndSettle();

      expect(UserService.instance.name, 'أحمد');
      expect(find.text(AppStrings.nameSavedMsg), findsOneWidget);
    });

    testWidgets('اسم فارغ يوقّف الحفظ ويبين رسالة خطأ', (tester) async {
      await UserService.instance.saveName('حيدر');
      await pumpSettings(tester);

      await tester.tap(find.text(AppStrings.settingsNameLabel));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text(AppStrings.save));
      await tester.pump();

      expect(find.text(AppStrings.nameEmptyError), findsOneWidget);
      // الحوار بعده مفتوح — الاسم القديم ما تغيّر
      expect(UserService.instance.name, 'حيدر');
    });
  });

  group('تسجيل الخروج', () {
    testWidgets('زر تسجيل الخروج يشتغل فعلياً ويرجع لشاشة البداية', (
      tester,
    ) async {
      await UserService.instance.saveName('حيدر');
      await pumpSettings(tester);

      await tester.tap(find.text(AppStrings.logout));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(UserService.instance.name, isEmpty);

      // نصرف مؤقت السبلاش (٢.٥ ثانية) حتى ما يبقى تايمر معلّق بعد الاختبار
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });
}
