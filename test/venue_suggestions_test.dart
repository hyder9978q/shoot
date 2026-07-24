import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/constants/admin_config.dart';
import 'package:shoot/core/constants/app_strings.dart';
import 'package:shoot/core/models/venue_suggestion.dart';
import 'package:shoot/core/services/venue_suggestions_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/features/admin/screens/admin_venue_suggestions_screen.dart';
import 'package:shoot/features/home/screens/home_screen.dart';
import 'package:shoot/features/venues/screens/my_venue_suggestions_screen.dart';
import 'package:shoot/features/venues/screens/suggest_venue_screen.dart';

/// ميزة "اقترح ملعب": التطابق التقريبي (يزيد عدّاد بدل سجل مكرر)،
/// منع الاحتساب المكرر لنفس اللاعب، التحقق من المدخلات، وتغيير الحالة
/// (المسؤول فقط).
void main() {
  final service = VenueSuggestionsService.instance;

  setUp(() => service.debugReset());
  tearDown(() {
    service.debugReset();
    AdminConfig.debugIsAdmin = null;
  });

  group('اقتراح جديد', () {
    testWidgets('ينسجّل قيد المراجعة بعدّاد واحد ويبين باقتراحاتي', (_) async {
      final isNew = await service.suggestVenue(
        name: 'ملعب الأمل',
        area: 'بغداد — الكرادة',
      );

      expect(isNew, isTrue);
      final mine = await service.mySuggestions();
      expect(mine, hasLength(1));
      expect(mine.first.name, 'ملعب الأمل');
      expect(mine.first.status, VenueSuggestionStatus.pending);
      expect(mine.first.requestCount, 1);
    });

    testWidgets('ينظّف المدخلات من الرموز الخطيرة ويقص الطول', (_) async {
      await service.suggestVenue(
        name: '<script>ملعب</script> الرشيد',
        area: 'بغداد',
        note: '<b>ملاحظة</b> عادية',
      );

      final mine = await service.mySuggestions();
      expect(mine.first.name, isNot(contains('<')));
      expect(mine.first.note, isNot(contains('<')));
    });

    testWidgets('يرفض اسم فاضي', (_) async {
      // نمرر الـ Future مباشرة ونستنى نتيجتها قبل أي نداء ثاني — نداء
      // ثاني متزامن وياها كان يرجع false بصمت (حماية الضغط المكرر)
      await expectLater(
        service.suggestVenue(name: '', area: 'بغداد'),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('يرفض منطقة فاضية', (_) async {
      await expectLater(
        service.suggestVenue(name: 'ملعب', area: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('يرفض رابط خرائط بدون https', (_) async {
      await expectLater(
        service.suggestVenue(
          name: 'ملعب',
          area: 'بغداد',
          mapsUrl: 'http://maps.example.com',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('يقبل رابط خرائط https ورقم عراقي صحيح', (_) async {
      final isNew = await service.suggestVenue(
        name: 'ملعب المدينة',
        area: 'بغداد',
        mapsUrl: 'https://maps.google.com/xyz',
        phone: '07701234567',
      );

      expect(isNew, isTrue);
      final mine = await service.mySuggestions();
      expect(mine.first.mapsUrl, 'https://maps.google.com/xyz');
      expect(mine.first.phone, '+9647701234567');
    });

    testWidgets('يرفض رقم ملعب غير صحيح', (_) async {
      await expectLater(
        service.suggestVenue(name: 'ملعب', area: 'بغداد', phone: '123'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('التطابق التقريبي', () {
    testWidgets('نفس الاسم والمنطقة بتشكيل ومسافات مختلفة = نفس المعرّف',
        (_) async {
      final a = VenueSuggestionsService.debugDocIdFor(
        'مَلْعَبُ  النجوم',
        'المنصور',
      );
      final b = VenueSuggestionsService.debugDocIdFor(
        'ملعب النجوم',
        'المنصور',
      );
      expect(a, b);
    });

    testWidgets('اقتراح نفس الملعب مرتين من نفس اللاعب ما يكرر السجل ولا العدّاد',
        (_) async {
      final first = await service.suggestVenue(
        name: 'ملعب النجوم',
        area: 'المنصور',
      );
      final second = await service.suggestVenue(
        name: '  ملعب   النجوم  ', // نفس الاسم بمسافات زايدة
        area: 'المنصور',
      );

      expect(first, isTrue);
      expect(second, isFalse, reason: 'مو أول اقتراح لهذا الملعب');

      final mine = await service.mySuggestions();
      // نفس اللاعب — ما يتكرر السجل وما يزيد العدّاد لأنه هو نفسه
      // اللي طلبه
      expect(mine, hasLength(1));
      expect(mine.first.requestCount, 1);
    });

    testWidgets('ملعبين مختلفين بالاسم أو المنطقة يبقون سجلات منفصلة',
        (_) async {
      await service.suggestVenue(name: 'ملعب النجوم', area: 'المنصور');
      await service.suggestVenue(name: 'ملعب النجوم', area: 'الكرادة');
      await service.suggestVenue(name: 'ملعب الرشيد', area: 'المنصور');

      final all = await service.allSuggestions();
      expect(all, hasLength(3));
    });
  });

  group('لوحة الإدارة', () {
    testWidgets('مرتّبة بعدد الطلبات — الأكثر أولاً', (_) async {
      await service.suggestVenue(name: 'ملعب أ', area: 'بغداد');
      await service.suggestVenue(name: 'ملعب ب', area: 'بغداد');

      final all = await service.allSuggestions();
      expect(all, hasLength(2));
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i - 1].requestCount,
          greaterThanOrEqualTo(all[i].requestCount),
        );
      }
    });

    testWidgets('تغيير الحالة ينعكس على الاقتراح', (_) async {
      await service.suggestVenue(name: 'ملعب الفتح', area: 'بغداد');
      final suggestion = (await service.allSuggestions()).first;

      await service.updateStatus(suggestion, VenueSuggestionStatus.added);

      final updated = (await service.allSuggestions()).first;
      expect(updated.status, VenueSuggestionStatus.added);
      // بقية البيانات ما تتغير بتغيير الحالة
      expect(updated.name, suggestion.name);
      expect(updated.requestCount, suggestion.requestCount);
    });
  });

  group('صلاحية الإدارة', () {
    tearDown(() => AdminConfig.debugIsAdmin = null);

    test('حساب عادي ما يعتبر مسؤول افتراضياً', () {
      AdminConfig.debugIsAdmin = null;
      // بوضع الاختبار ما بيه UID بقائمة adminUids افتراضياً
      expect(AdminConfig.isCurrentUserAdmin, isFalse);
    });

    test('debugIsAdmin يفرض القيمة بالاختبارات', () {
      AdminConfig.debugIsAdmin = true;
      expect(AdminConfig.isCurrentUserAdmin, isTrue);
      AdminConfig.debugIsAdmin = false;
      expect(AdminConfig.isCurrentUserAdmin, isFalse);
    });
  });

  group('الشاشات', () {
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

    testWidgets('نموذج الاقتراح: يرفض الإرسال الفاضي ويقبل بعد التعبئة',
        (tester) async {
      await tester.pumpWidget(app(const SuggestVenueScreen()));
      await tester.pumpAndSettle();

      // إرسال فاضي: يبين أخطاء الحقول المطلوبة، ما يسكّر الشاشة
      await tester.tap(find.text(AppStrings.suggestSubmitAction));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.fieldNameError), findsOneWidget);
      expect(find.text(AppStrings.suggestAreaError), findsOneWidget);
      expect(find.byType(SuggestVenueScreen), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'ملعب الاختبار');
      await tester.enterText(fields.at(1), 'بغداد');
      await tester.tap(find.text(AppStrings.suggestSubmitAction));
      await tester.pumpAndSettle();

      // نجح الإرسال: الشاشة تسكّر وتبين اقتراحاتي
      expect(find.byType(SuggestVenueScreen), findsNothing);
      final mine = await VenueSuggestionsService.instance.mySuggestions();
      expect(mine.any((s) => s.name == 'ملعب الاختبار'), isTrue);
    });

    testWidgets('زر "اقترح ملعب" بالرئيسية يفتح شاشة النموذج', (tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const Scaffold(body: HomeTab())));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.suggestVenueCta), findsOneWidget);
      await tester.tap(find.text(AppStrings.suggestVenueCta));
      await tester.pumpAndSettle();

      expect(find.byType(SuggestVenueScreen), findsOneWidget);
    });

    testWidgets('اقتراحاتي: تبين حالة الاقتراح وتفتح النموذج من الحالة الفارغة',
        (tester) async {
      await tester.pumpWidget(app(const MyVenueSuggestionsScreen()));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.noSuggestionsTitle), findsOneWidget);

      await service.suggestVenue(name: 'ملعب الحي', area: 'بغداد');
      // نعيد بناء الشاشة حتى تلتقط الاقتراح الجديد (تسمع revision)
      await tester.pumpWidget(app(const MyVenueSuggestionsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ملعب الحي'), findsOneWidget);
      expect(find.text(VenueSuggestionStatus.pending.label), findsOneWidget);
    });

    testWidgets('لوحة الإدارة: مرتّبة بعدد الطلبات وتغيّر الحالة', (tester) async {
      await service.suggestVenue(name: 'ملعب أ', area: 'بغداد');
      await service.suggestVenue(name: 'ملعب ب', area: 'بصرة');

      await tester.pumpWidget(app(const AdminVenueSuggestionsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ملعب أ'), findsOneWidget);
      expect(find.text('ملعب ب'), findsOneWidget);

      // نغيّر حالة أول اقتراح إلى "انضاف"
      await tester.tap(find.byIcon(Icons.edit_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(VenueSuggestionStatus.added.label).last);
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.adminStatusUpdated),
        findsOneWidget,
        reason: 'رسالة تأكيد التحديث تبين',
      );
    });
  });
}
