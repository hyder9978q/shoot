import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/features/owner/screens/field_manage_screen.dart';

/// شاشة "إدارة الملعب" — تغطية اختبارية لخلل حقيقي انلگى بجهاز فعلي:
/// بعد الكتابة بحقل رقم تواصل المنشأة وإغلاق لوحة المفاتيح، كان
/// التمرير يتجمّد وزر "احفظ التعديلات" يصير غير قابل للوصول لأنه كان
/// جزء من محتوى ListView القابل للتمرير. الإصلاح: الزر ثابت الآن
/// بـ bottomNavigationBar خارج المحتوى القابل للتمرير.
void main() {
  final fields = FieldsService.instance;

  setUp(() => fields.debugReset());
  tearDown(() => fields.debugReset());

  Future<Field> owned() async {
    final all = await fields.myFields('mock-user');
    return all.first;
  }

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

  testWidgets(
    'زر "احفظ التعديلات" ثابت أسفل الشاشة (مو داخل المحتوى القابل للتمرير)',
    (tester) async {
      final field = await owned();
      await tester.pumpWidget(app(FieldManageScreen(field: field)));
      await tester.pumpAndSettle();

      // الزر لازم يبين فوراً بدون أي تمرير — لأنه بـ bottomNavigationBar
      expect(find.text('احفظ التعديلات'), findsOneWidget);
    },
  );

  testWidgets(
    'الكتابة برقم تواصل المنشأة وإغلاق لوحة المفاتيح ما يكسر الوصول لزر الحفظ، والحفظ ينجح',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final field = await owned();
      await tester.pumpWidget(app(FieldManageScreen(field: field)));
      await tester.pumpAndSettle();

      // نكتب برقم تواصل المنشأة — نفس الحقل اللي سبب التجمّد بالجهاز الحقيقي
      await tester.enterText(
        find.byType(TextField).at(4),
        '07709998877',
      );
      await tester.pump();

      // نغلق لوحة المفاتيح (زر "تم" الظاهري) — هذا بالضبط اللي سبب
      // تجمّد التمرير سابقاً
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // زر الحفظ لازم يبقى موجود وقابل للضغط بدون أي حاجة للتمرير
      final saveButton = find.text('احفظ التعديلات');
      expect(saveButton, findsOneWidget);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('انحفظت التعديلات ✅'), findsOneWidget);

      final updated = (await fields.myFields('mock-user')).firstWhere(
        (f) => f.id == field.id,
      );
      expect(updated.contactPhone, '+9647709998877');
    },
  );

  testWidgets(
    'تعديل معلومات أساسية وطريقة دفع سوا وحفظهم بضغطة وحدة',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final field = await owned();
      expect(field.paymentCashOnArrival, isTrue);

      await tester.pumpWidget(app(FieldManageScreen(field: field)));
      await tester.pumpAndSettle();

      // بطاقة "طرق الدفع" آخر الصفحة — لازم نمرّر الها قبل ما نلگاها.
      // نحدد الـ ListView الرئيسي بمفتاحه (مو find.byType(Scrollable)
      // لأنه فيه أكثر من Scrollable بالصفحة — صفوف الصور الأفقية مثلاً)
      final mainScroll = find.byKey(
        const PageStorageKey<String>('field_manage_scroll'),
      );
      await tester.drag(mainScroll, const Offset(0, -2000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('كاش عند الوصول'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('احفظ التعديلات'));
      await tester.pumpAndSettle();

      expect(find.text('انحفظت التعديلات ✅'), findsOneWidget);

      final updated = (await fields.myFields('mock-user')).firstWhere(
        (f) => f.id == field.id,
      );
      expect(updated.paymentCashOnArrival, isFalse);
      // العربون يبقى مفعّل لأنه أصلاً وحيد شغال ونحتاج طريقة وحدة عالأقل
      expect(updated.paymentDeposit, isTrue);
    },
  );

  testWidgets('يرفض رقم تواصل منشأة غير عراقي صحيح ولا يحفظ شي', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final field = await owned();
    await tester.pumpWidget(app(FieldManageScreen(field: field)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(4), '12345');
    await tester.pump();

    await tester.tap(find.text('احفظ التعديلات'));
    await tester.pumpAndSettle();

    expect(
      find.text('رقم تواصل المنشأة لازم يبدي بـ07 ويكون 11 رقم'),
      findsOneWidget,
    );

    final unchanged = (await fields.myFields('mock-user')).firstWhere(
      (f) => f.id == field.id,
    );
    expect(unchanged.contactPhone, field.contactPhone);
  });
}
