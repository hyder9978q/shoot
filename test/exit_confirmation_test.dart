import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/constants/app_strings.dart';
import 'package:shoot/core/services/bookings_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/services/user_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/features/owner/screens/owner_shell.dart';
import 'package:shoot/features/shell/main_shell.dart';

/// زر الرجوع الأصلي لأندرويد كان يخرج من التطبيق فوراً بدون تأكيد من أي
/// تبويب رئيسي (لاعب أو صاحب منشأة). الإصلاح: أول ضغطة تبين تنبيه "دزّ رجوع
/// مرة ثانية"، وبس الضغطة الثانية خلال ثانيتين تسكر التطبيق فعلياً.
void main() {
  Widget app(Widget home) => MaterialApp(
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
    home: home,
  );

  group('حساب اللاعب — تأكيد الخروج', () {
    setUp(() async {
      UserService.instance.resetForSignOut();
      await UserService.instance.saveAccountType('player');
      BookingsService.instance.debugReset();
    });
    tearDown(() {
      UserService.instance.resetForSignOut();
      BookingsService.instance.debugReset();
    });

    testWidgets('أول ضغطة رجوع تبين تنبيه وما تسكر التطبيق', (tester) async {
      var popCalls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') popCalls++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(app(const MainShell()));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text(AppStrings.pressBackAgainToExit), findsOneWidget);
      expect(popCalls, 0);
    });

    testWidgets('ضغطتين متتاليتين خلال ثانيتين تسكر التطبيق فعلياً', (
      tester,
    ) async {
      var popCalls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') popCalls++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(app(const MainShell()));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(popCalls, 1);
    });

    testWidgets(
      'زر الرجوع داخل شاشة مفتوحة فوق التبويبات يرجّع للخلف عادي مو يسكر التطبيق',
      (tester) async {
        tester.view.physicalSize = const Size(420, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        var popCalls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'SystemNavigator.pop') popCalls++;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await tester.pumpWidget(app(const MainShell()));
        await tester.pumpAndSettle();

        // نفتح شاشة فرعية فوق التبويبات (الإعدادات) من تبويب "حسابي"
        await tester.tap(find.text('حسابي').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('الإعدادات'));
        await tester.pumpAndSettle();

        // الرجوع هنا يجب يسكر شاشة الإعدادات بس، مو يخرج من التطبيق
        // ولا حتى يبين تنبيه الخروج
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(popCalls, 0);
        expect(find.text(AppStrings.pressBackAgainToExit), findsNothing);
      },
    );
  });

  group('حساب صاحب المنشأة — تأكيد الخروج', () {
    setUp(() async {
      UserService.instance.resetForSignOut();
      await UserService.instance.saveAccountType('owner');
      FieldsService.instance.debugReset();
    });
    tearDown(() {
      UserService.instance.resetForSignOut();
      FieldsService.instance.debugReset();
    });

    testWidgets('أول ضغطة رجوع تبين تنبيه وما تسكر التطبيق', (tester) async {
      var popCalls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') popCalls++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(app(const OwnerShell()));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.text(AppStrings.pressBackAgainToExit), findsOneWidget);
      expect(popCalls, 0);
    });

    testWidgets('ضغطتين متتاليتين خلال ثانيتين تسكر التطبيق فعلياً', (
      tester,
    ) async {
      var popCalls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') popCalls++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(app(const OwnerShell()));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(popCalls, 1);
    });
  });
}
