import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/constants/admin_config.dart';
import 'package:shoot/core/constants/app_strings.dart';
import 'package:shoot/core/models/booking.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/services/bookings_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/services/local_store.dart';
import 'package:shoot/core/services/user_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/core/utils/date_labels.dart';
import 'package:shoot/features/admin/screens/admin_pending_venues_screen.dart';
import 'package:shoot/features/owner/screens/owner_venues_screen.dart';

/// إصلاحات التدقيق الأمني: مراجعة المنشآت الجديدة قبل نشرها، وفصل
/// بيانات التواصل عن مستند الحجز المقروء من الكل.
void main() {
  final fields = FieldsService.instance;
  final bookings = BookingsService.instance;

  setUp(() {
    DateLabels.debugNow = DateTime(2026, 7, 15);
    fields.debugReset();
    bookings.debugReset();
    UserService.instance.resetForSignOut();
    AdminConfig.debugIsAdmin = null;
  });

  tearDown(() {
    DateLabels.debugNow = null;
    fields.debugReset();
    bookings.debugReset();
    UserService.instance.resetForSignOut();
    AdminConfig.debugIsAdmin = null;
  });

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar')],
    theme: AppTheme.light,
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );

  Future<Field> addVenue() => fields.createField(
    name: 'ملعب المراجعة',
    area: 'الجادرية',
    city: 'بغداد',
    sport: Sport.football,
    pricePerHour: 20000,
    openHour: 16,
    closeHour: 24,
    contactPhone: '07701112233',
  );

  group('مراجعة المنشأة الجديدة', () {
    testWidgets('المنشأة الجديدة تنولد معطّلة (بانتظار المراجعة)', (_) async {
      final created = await addVenue();
      expect(created.isActive, isFalse);
    });

    testWidgets('صاحبها يشوفها بمنشآتي رغم إنها ما انفعّلت', (_) async {
      final created = await addVenue();
      final mine = await fields.myFields('mock-user');
      expect(mine.map((f) => f.id), contains(created.id));
    });

    testWidgets('تبين بقائمة المسؤول المعلّقة وتنشال منها بعد التفعيل', (
      _,
    ) async {
      final created = await addVenue();
      expect((await fields.pendingFields()).map((f) => f.id), contains(created.id));

      AdminConfig.debugIsAdmin = true;
      final activated = await fields.setFieldActive(created, true);
      expect(activated.isActive, isTrue);
      expect(
        (await fields.pendingFields()).map((f) => f.id),
        isNot(contains(created.id)),
      );
    });

    testWidgets('غير المسؤول ما يگدر يفعّل منشأة', (_) async {
      final created = await addVenue();
      AdminConfig.debugIsAdmin = false;
      expect(() => fields.setFieldActive(created, true), throwsStateError);
    });

    testWidgets('تبويب منشآتي يعرض شارة "بانتظار المراجعة"', (tester) async {
      final created = await addVenue();
      await tester.pumpWidget(
        wrap(OwnerVenuesScreen(fields: [created], onChanged: () {})),
      );
      await tester.pump();
      expect(find.text(AppStrings.venuePendingBadge), findsOneWidget);
    });

    testWidgets('لوحة المسؤول تعرض المنشأة المعلّقة وزر التفعيل', (
      tester,
    ) async {
      final created = await addVenue();
      AdminConfig.debugIsAdmin = true;

      await tester.pumpWidget(wrap(const AdminPendingVenuesScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('pending-venue-${created.id}')), findsOneWidget);
      expect(find.text(AppStrings.adminActivateVenueAction), findsOneWidget);

      await tester.tap(find.text(AppStrings.adminActivateVenueAction));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('pending-venue-${created.id}')), findsNothing);
      expect(find.text(AppStrings.adminNoPendingVenues), findsOneWidget);
    });
  });

  group('خصوصية بيانات التواصل', () {
    const booking = Booking(
      id: 'f1_2026-07-15_20',
      userId: 'mock-user',
      fieldId: 'f1',
      fieldName: 'ملعب النجوم',
      area: 'المنصور',
      city: 'بغداد',
      sport: Sport.football,
      date: '2026-07-15',
      hour: 20,
      deposit: 5000,
      userPhone: '+9647701112233',
      customerName: 'أبو أحمد',
      note: 'يوصل متأخر',
    );

    test('مستند الحجز الرئيسي ما بيه ولا رقم ولا اسم زبون', () {
      final map = booking.toMap();
      expect(map.containsKey('userPhone'), isFalse);
      expect(map.containsKey('customerName'), isFalse);
      expect(map.containsKey('note'), isFalse);
      // معلومات الوقت المحجوز تبقى عامة — منها تنبني شبكة الأوقات
      expect(map['fieldId'], 'f1');
      expect(map['date'], '2026-07-15');
      expect(map['hour'], 20);
    });

    test('المستند الفرعي الخاص يحمل بيانات التواصل وهوية الحجز', () {
      final contact = booking.contactMap;
      expect(contact['userPhone'], '+9647701112233');
      expect(contact['customerName'], 'أبو أحمد');
      expect(contact['note'], 'يوصل متأخر');
      // fieldId/date/hour منسوخة حتى تطابقها القواعد بمعرّف المستند
      expect(
        '${contact['fieldId']}_${contact['date']}_${contact['hour']}',
        booking.id,
      );
    });

    test('withContact يعبّي الحجز من المستند الفرعي', () {
      const bare = Booking(
        id: 'f1_2026-07-15_20',
        userId: 'mock-user',
        fieldId: 'f1',
        fieldName: 'ملعب النجوم',
        area: 'المنصور',
        city: 'بغداد',
        sport: Sport.football,
        date: '2026-07-15',
        hour: 20,
        deposit: 5000,
      );
      expect(bare.userPhone, isEmpty);

      final filled = bare.withContact(const {
        'userPhone': '+9647709998877',
        'customerName': 'زبون',
        'note': '',
      });
      expect(filled.userPhone, '+9647709998877');
      expect(filled.customerName, 'زبون');
      expect(filled.id, bare.id);
      expect(filled.deposit, 5000);
    });
  });

  group('جلسة الدخول المحلية', () {
    test('محصورة بوضع التجربة — ما تعتمد كدليل دخول بالإنتاج', () async {
      // وضع التجربة شغال بالاختبارات، فالعلم المحفوظ يُقرأ عادي
      await LocalStore.setSignedIn(true);
      expect(await LocalStore.signedIn, isTrue);

      await LocalStore.setSignedIn(false);
      expect(await LocalStore.signedIn, isFalse);
    });
  });
}
