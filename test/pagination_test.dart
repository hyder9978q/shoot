import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/core/widgets/field_card.dart';
import 'package:shoot/features/home/screens/home_screen.dart';
import 'package:shoot/features/home/widgets/play_now_section.dart';

/// تحميل الملاعب على دفعات — الخدمة والواجهة.
///
/// نصغّر حجم الدفعة بالاختبار (debugPageSize) حتى البيانات التجريبية
/// تكفي لأكثر من دفعة وحدة.
void main() {
  final service = FieldsService.instance;

  setUp(() {
    FieldsService.debugPageSize = 3;
    service.debugReset();
  });

  tearDown(() {
    FieldsService.debugPageSize = null;
    service.debugReset();
  });

  group('خدمة الملاعب — الدفعات', () {
    test('أول تحميل يجيب دفعة وحدة فقط، ويبقى بعدها ملاعب', () async {
      final first = await service.loadFields();

      expect(first, hasLength(3));
      expect(service.hasMore, isTrue);
    });

    test('التحميل الثاني يضيف الدفعة الجاية بدون تكرار', () async {
      await service.loadFields();
      final after = await service.loadMore();

      expect(after, hasLength(6));
      expect(
        after.map((f) => f.id).toSet(),
        hasLength(6),
        reason: 'ما لازم يتكرر أي ملعب بين الدفعات',
      );
    });

    test('loadAllFields تكمّل كل الدفعات وتوقف بالنهاية', () async {
      final all = await service.loadAllFields();

      expect(all.length, greaterThan(6), reason: 'لازم تتجاوز أول دفعتين');
      expect(service.hasMore, isFalse);
      expect(all.map((f) => f.id).toSet(), hasLength(all.length));
    });

    test('طلبين بنفس اللحظة يشتركون بنفس الدفعة (ما ننزلها مرتين)', () async {
      final results = await Future.wait([
        service.loadFields(),
        service.loadFields(),
      ]);

      expect(results.first, hasLength(3));
      expect(results.last, hasLength(3));
    });

    test('loadMore بعد النهاية ما تضيف شي', () async {
      final all = await service.loadAllFields();
      final again = await service.loadMore();

      expect(again, hasLength(all.length));
      expect(service.hasMore, isFalse);
    });

    test('ملاعب المالك تدور بالقائمة كاملة مو بأول دفعة', () async {
      // mock-user يملك ملاعب مو كلها بأول دفعة
      final mine = await service.myFields('mock-user');

      expect(mine, isNotEmpty);
      expect(service.hasMore, isFalse, reason: 'لازم تكون كمّلت التحميل');
    });
  });

  group('الرئيسية — التمرير يجيب دفعة جديدة', () {
    Widget app() => MaterialApp(
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
          home: const Scaffold(body: HomeTab()),
        );

    testWidgets('تبين أول دفعة، وبالتمرير لأسفل تزيد البطاقات',
        (tester) async {
      PlayNowSection.debugNowHour = 24; // نخفي قسم "العب اليوم"
      addTearDown(() => PlayNowSection.debugNowHour = null);
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final firstBatch = tester.widgetList<FieldCard>(find.byType(FieldCard));
      expect(
        firstBatch.length,
        lessThanOrEqualTo(3),
        reason: 'أول دفعة فقط تنبنى',
      );
      expect(FieldsService.instance.hasMore, isTrue);

      // نمرر لأسفل → المستمع يطلب الدفعة الجاية
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(
        FieldsService.instance.search().length,
        greaterThan(3),
        reason: 'التمرير لازم يجيب دفعة إضافية',
      );
    });
  });
}
