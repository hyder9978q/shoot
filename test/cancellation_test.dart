import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/constants/app_features.dart';
import 'package:shoot/core/constants/app_strings.dart';
import 'package:shoot/core/models/cancellation.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/services/bookings_service.dart';
import 'package:shoot/core/services/cancellations_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/core/utils/date_labels.dart';
import 'package:shoot/core/widgets/reliability_badge.dart';
import 'package:shoot/features/bookings/screens/replacement_screen.dart';

/// "حلّال المشاكل": الإلغاء من صاحب الملعب → بديل فوري + ضمان.
void main() {
  final fields = FieldsService.instance;
  final bookings = BookingsService.instance;
  final cancels = CancellationsService.instance;

  setUp(() {
    DateLabels.debugNow = DateTime(2026, 7, 15);
    cancels.debugReset();
  });

  tearDown(() {
    DateLabels.debugNow = null;
    CancellationsService.debugReliability = null;
    cancels.debugReset();
  });

  /// ملعب يملكه المستخدم التجريبي (mock-user)
  Future<Field> ownedField() async {
    final all = await fields.loadAllFields();
    return all.firstWhere((f) => f.ownerId == 'mock-user');
  }

  group('إلغاء صاحب الملعب', () {
    testWidgets('يسجّل الإلغاء ويحرّر الوقت للاعبين الثانين', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1); // باچر: كل الأوقات فاضية
      final slot = TimeSlot(hour: field.openHour, isBooked: false);
      final booking = await bookings.createBooking(field, slot, date: date);

      // قبل الإلغاء: الوقت محجوز
      var taken = await bookings.takenFieldIdsAt(date, slot.hour);
      expect(taken, contains(field.id));

      final record = await cancels.cancelByOwner(
        field,
        booking,
        reason: 'صيانة الأرضية',
      );

      expect(record.playerId, booking.userId);
      expect(record.fieldId, field.id);
      expect(record.reason, 'صيانة الأرضية');

      // بعد الإلغاء: الوقت تحرر
      taken = await bookings.takenFieldIdsAt(date, slot.hour);
      expect(taken, isNot(contains(field.id)));
    });

    testWidgets('ينظّف سبب الإلغاء من الرموز الخطيرة', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(2);
      final slot = TimeSlot(hour: field.openHour, isBooked: false);
      final booking = await bookings.createBooking(field, slot, date: date);

      final record = await cancels.cancelByOwner(
        field,
        booking,
        reason: '<script>alert(1)</script> صيانة',
      );

      expect(record.reason, isNot(contains('<')));
      expect(record.reason, isNot(contains('>')));
      expect(record.reason, contains('صيانة'));
    });

    testWidgets('ما يخلي غير المالك يلغي', (_) async {
      final all = await fields.loadAllFields();
      final notMine = all.firstWhere((f) => f.ownerId != 'mock-user');
      final date = DateLabels.dateFor(3);
      final slot = TimeSlot(hour: notMine.openHour, isBooked: false);
      final booking = await bookings.createBooking(notMine, slot, date: date);

      expect(
        () => cancels.cancelByOwner(notMine, booking),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('سجل اللاعب والضمان', () {
    testWidgets('الإلغاء ينحسب "مو بذنبك" ويعطي رصيد ضمان', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final booking = await bookings.createBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: date,
      );
      await cancels.cancelByOwner(field, booking);

      expect(await cancels.guaranteedCredits(), 1);
      expect((await cancels.unseen()), hasLength(1));

      // استخدم الضمان → ينزل الرصيد
      final mine = await cancels.myCancellations();
      await cancels.markCompensated(mine.first);

      expect(await cancels.guaranteedCredits(), 0);
    });

    testWidgets('الحجز البديل يجي بدون عربون ومعلّم كمضمون', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final replacement = await bookings.createBooking(
        field,
        TimeSlot(hour: field.openHour + 1, isBooked: false),
        date: date,
        replacesCancellationId: 'c1',
        depositWaived: true,
      );

      expect(replacement.deposit, 0);
      expect(replacement.depositWaived, isTrue);
      expect(replacement.isGuaranteed, isTrue);
    });
  });

  group('البدائل', () {
    testWidgets('بنفس المدينة والرياضة والوكت، والأقرب أول', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final booking = await bookings.createBooking(
        field,
        TimeSlot(hour: 18, isBooked: false),
        date: date,
      );
      final record = await cancels.cancelByOwner(field, booking);

      final alternatives = await cancels.findAlternatives(record);

      expect(alternatives, isNotEmpty);
      for (final a in alternatives) {
        expect(a.field.city, record.city, reason: 'نفس المدينة');
        expect(a.field.sport, record.sport, reason: 'نفس الرياضة');
        expect(a.field.id, isNot(record.fieldId), reason: 'مو نفس الملعب');
        expect(
          record.hour,
          inInclusiveRange(a.field.openHour, a.field.closeHour - 1),
          reason: 'الملعب دوامه يغطي الساعة',
        );
      }

      // مرتبة بالأقرب
      final withDistance =
          alternatives.where((a) => a.hasDistance).toList();
      for (var i = 1; i < withDistance.length; i++) {
        expect(
          withDistance[i].distanceKm,
          greaterThanOrEqualTo(withDistance[i - 1].distanceKm),
        );
      }
    });

    testWidgets('الملعب المحجوز بنفس الوكت ما ينعرض كبديل', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final booking = await bookings.createBooking(
        field,
        TimeSlot(hour: 18, isBooked: false),
        date: date,
      );
      final record = await cancels.cancelByOwner(field, booking);

      final before = await cancels.findAlternatives(record);
      expect(before, isNotEmpty);

      // نحجز أول بديل بنفس الوكت → لازم يختفي من القائمة
      final target = before.first.field;
      await bookings.createBooking(
        target,
        const TimeSlot(hour: 18, isBooked: false),
        date: date,
      );

      final after = await cancels.findAlternatives(record);
      expect(after.map((a) => a.field.id), isNot(contains(target.id)));
    });
  });

  group('شاشة البدائل', () {
    Widget app(Widget home) => MaterialApp(
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

    testWidgets('تعرض البدائل وزر الحجز، وتعلّم الإلغاء كمقروء',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final booking = await bookings.createBooking(
        field,
        const TimeSlot(hour: 18, isBooked: false),
        date: date,
      );
      final record = await cancels.cancelByOwner(field, booking);
      expect(await cancels.unseen(), hasLength(1));

      await tester.pumpWidget(app(ReplacementScreen(cancellation: record)));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.replacementTitle), findsOneWidget);
      expect(find.text(AppStrings.bookReplacement), findsWidgets);
      // فتح الشاشة = شاف الإشعار
      expect(await cancels.unseen(), isEmpty);
    });

    testWidgets('تبين شارة الضمان لما الميزة مفعّلة', (tester) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AppFeatures.guaranteeWaivesDeposit = true;

      final field = await ownedField();
      final booking = await bookings.createBooking(
        field,
        const TimeSlot(hour: 19, isBooked: false),
        date: DateLabels.dateFor(1),
      );
      final record = await cancels.cancelByOwner(field, booking);

      await tester.pumpWidget(app(ReplacementScreen(cancellation: record)));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.guaranteedExplain), findsOneWidget);
    });
  });

  group('نسبة الالتزام', () {
    Widget wrap(Widget child) => MaterialApp(
          theme: AppTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: child),
          ),
        );

    testWidgets('تنخفي إذا التاريخ ما يكفي', (tester) async {
      CancellationsService.debugReliability =
          const FieldReliability(kept: 2, cancelled: 0);

      await tester.pumpWidget(wrap(const ReliabilityBadge(fieldId: 'f1')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified_rounded), findsNothing);
    });

    testWidgets('ملعب ملتزم يطلع بشارة خضراء', (tester) async {
      CancellationsService.debugReliability =
          const FieldReliability(kept: 20, cancelled: 0);

      await tester.pumpWidget(wrap(const ReliabilityBadge(fieldId: 'f1')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('ملعب كثير إلغاءات يطلع بتحذير', (tester) async {
      CancellationsService.debugReliability =
          const FieldReliability(kept: 6, cancelled: 4);

      await tester.pumpWidget(wrap(const ReliabilityBadge(fieldId: 'f1')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text(AppStrings.reliabilityRisky), findsOneWidget);
    });

    test('الحساب: ٦٠٪ = ٦ أكملها و٤ ألغاها', () {
      const value = FieldReliability(kept: 6, cancelled: 4);
      expect(value.percent, 60);
      expect(value.isRisky, isTrue);
      expect(value.hasEnoughData, isTrue);
    });
  });
}
