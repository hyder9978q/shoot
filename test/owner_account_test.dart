import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/services/bookings_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/services/user_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/core/utils/date_labels.dart';
import 'package:shoot/features/auth/screens/account_type_screen.dart';
import 'package:shoot/features/owner/screens/add_venue_screen.dart';
import 'package:shoot/features/owner/screens/owner_shell.dart';
import 'package:shoot/features/profile/screens/settings_screen.dart';
import 'package:shoot/features/shell/main_shell.dart';

/// حساب صاحب المنشأة المنفصل: نوع الحساب، لوحة التحكم، منشآتي (إضافة
/// منشأة جديدة)، الحجوزات المجمّعة، والإعدادات الخاصة.
void main() {
  final bookings = BookingsService.instance;
  final fields = FieldsService.instance;

  setUp(() {
    DateLabels.debugNow = DateTime(2026, 7, 15);
    bookings.debugReset();
    fields.debugReset();
    UserService.instance.resetForSignOut();
    UserService.debugAccountType = null;
  });

  tearDown(() {
    DateLabels.debugNow = null;
    bookings.debugReset();
    fields.debugReset();
    UserService.instance.resetForSignOut();
    UserService.debugAccountType = null;
  });

  Future<Field> owned() async {
    final all = await fields.loadAllFields();
    return all.firstWhere((f) => f.ownerId == 'mock-user');
  }

  group('UserService.accountType', () {
    test('يحفظ نوع الحساب لاعب أو صاحب منشأة', () async {
      await UserService.instance.saveAccountType('owner');
      expect(UserService.instance.accountType, 'owner');
      expect(UserService.instance.isOwner, isTrue);

      await UserService.instance.saveAccountType('player');
      expect(UserService.instance.accountType, 'player');
      expect(UserService.instance.isOwner, isFalse);
    });

    test('يرفض قيمة غير صالحة', () {
      expect(
        () => UserService.instance.saveAccountType('admin'),
        throwsArgumentError,
      );
    });

    test('بوضع التجربة: لاعب افتراضياً، أو ما يحدده debugAccountType', () async {
      await UserService.instance.load();
      expect(UserService.instance.accountType, 'player');

      UserService.instance.resetForSignOut();
      UserService.debugAccountType = 'owner';
      await UserService.instance.load();
      expect(UserService.instance.accountType, 'owner');
    });
  });

  group('FieldsService.createField', () {
    testWidgets('يضيف منشأة جديدة يملكها المستخدم الحالي', (_) async {
      final before = (await fields.myFields('mock-user')).length;

      final created = await fields.createField(
        name: 'صالة النخبة',
        area: 'الكرادة',
        city: 'بغداد',
        sport: Sport.gym,
        pricePerHour: 20000,
        openHour: 8,
        closeHour: 23,
        contactPhone: '07701112233',
      );

      expect(created.name, 'صالة النخبة');
      expect(created.sport, Sport.gym);
      expect(created.ownerId, 'mock-user');
      expect(created.rating, 0);
      expect(created.reviewsCount, 0);

      final after = await fields.myFields('mock-user');
      expect(after.length, before + 1);
      expect(after.map((f) => f.name), contains('صالة النخبة'));
    });

    testWidgets('ينظّف الاسم من الرموز الخطيرة', (_) async {
      final created = await fields.createField(
        name: '<script>alert(1)</script> ملعبي',
        area: 'المنصور',
        city: 'بغداد',
        sport: Sport.football,
        pricePerHour: 15000,
        openHour: 16,
        closeHour: 24,
        contactPhone: '07701112233',
      );
      expect(created.name, isNot(contains('<')));
      expect(created.name, contains('ملعبي'));
    });

    testWidgets('يرفض اسم فارغ', (_) async {
      expect(
        () => fields.createField(
          name: '   ',
          area: 'المنصور',
          city: 'بغداد',
          sport: Sport.football,
          pricePerHour: 15000,
          openHour: 16,
          closeHour: 24,
          contactPhone: '07701112233',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('يرفض سعر صفر أو سالب', (_) async {
      expect(
        () => fields.createField(
          name: 'ملعبي',
          area: 'المنصور',
          city: 'بغداد',
          sport: Sport.football,
          pricePerHour: 0,
          openHour: 16,
          closeHour: 24,
          contactPhone: '07701112233',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('يرفض ساعات دوام غير منطقية', (_) async {
      expect(
        () => fields.createField(
          name: 'ملعبي',
          area: 'المنصور',
          city: 'بغداد',
          sport: Sport.football,
          pricePerHour: 15000,
          openHour: 20,
          closeHour: 10,
          contactPhone: '07701112233',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('منشأة موجودة تبقى غير متأثرة', (_) async {
      final field = await owned();
      expect(field.ownerId, 'mock-user');
    });
  });

  group('رقم تواصل المنشأة — الخصوصية', () {
    testWidgets('الإنشاء يرفض بدون رقم تواصل', (_) async {
      expect(
        () => fields.createField(
          name: 'ملعبي',
          area: 'المنصور',
          city: 'بغداد',
          sport: Sport.football,
          pricePerHour: 15000,
          openHour: 16,
          closeHour: 24,
          contactPhone: '',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('الإنشاء يرفض رقم غير عراقي صحيح', (_) async {
      expect(
        () => fields.createField(
          name: 'ملعبي',
          area: 'المنصور',
          city: 'بغداد',
          sport: Sport.football,
          pricePerHour: 15000,
          openHour: 16,
          closeHour: 24,
          contactPhone: '12345',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('الإنشاء يحفظ رقم التواصل بصيغة دولية', (_) async {
      final created = await fields.createField(
        name: 'ملعبي',
        area: 'المنصور',
        city: 'بغداد',
        sport: Sport.football,
        pricePerHour: 15000,
        openHour: 16,
        closeHour: 24,
        contactPhone: '07701112233',
      );
      expect(created.contactPhone, '+9647701112233');
    });

    testWidgets('تعديل منشأة موجودة يسمح بترك رقم التواصل فاضي', (_) async {
      final field = await owned();
      final updated = await fields.updateFieldInfo(
        field,
        name: field.name,
        area: field.area,
        city: field.city,
        sport: field.sport,
        pricePerHour: field.pricePerHour,
        openHour: field.openHour,
        closeHour: field.closeHour,
        isOpen: field.isOpen,
        contactPhone: '',
      );
      expect(updated.contactPhone, isEmpty);
    });

    testWidgets('تعديل منشأة موجودة يرفض رقم تواصل غلط لو انكتب', (_) async {
      final field = await owned();
      expect(
        () => fields.updateFieldInfo(
          field,
          name: field.name,
          area: field.area,
          city: field.city,
          sport: field.sport,
          pricePerHour: field.pricePerHour,
          openHour: field.openHour,
          closeHour: field.closeHour,
          isOpen: field.isOpen,
          contactPhone: '0770',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('تعديل منشأة موجودة يحفظ رقم تواصل صحيح بصيغة دولية', (
      _,
    ) async {
      final field = await owned();
      final updated = await fields.updateFieldInfo(
        field,
        name: field.name,
        area: field.area,
        city: field.city,
        sport: field.sport,
        pricePerHour: field.pricePerHour,
        openHour: field.openHour,
        closeHour: field.closeHour,
        isOpen: field.isOpen,
        contactPhone: '07709998877',
      );
      expect(updated.contactPhone, '+9647709998877');
    });
  });

  group('BookingsService.ownerBookings', () {
    testWidgets('يجمع حجوزات كل منشآت المالك ويرتّبها', (_) async {
      final all = await fields.loadAllFields();
      final owned = all.where((f) => f.ownerId == 'mock-user').toList();
      expect(owned.length, greaterThanOrEqualTo(2));

      final f1 = owned[0];
      final f2 = owned[1];
      final tomorrow = DateLabels.dateFor(1);
      final dayAfter = DateLabels.dateFor(2);

      await bookings.createBooking(
        f1,
        TimeSlot(hour: f1.openHour, isBooked: false),
        date: dayAfter,
      );
      await bookings.createBooking(
        f2,
        TimeSlot(hour: f2.openHour, isBooked: false),
        date: tomorrow,
      );

      final upcoming = await bookings.ownerBookings([f1.id, f2.id]);
      expect(upcoming.length, 2);
      // الأقرب أول
      expect(upcoming.first.date, tomorrow);
      expect(upcoming.last.date, dayAfter);
    });

    testWidgets('قائمة فاضية بدون منشآت', (_) async {
      final result = await bookings.ownerBookings(const []);
      expect(result, isEmpty);
    });
  });

  group('شاشة اختيار نوع الحساب', () {
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

    testWidgets('اختيار "أني لاعب" يفتح واجهة اللاعب', (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const AccountTypeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('أني لاعب'), findsOneWidget);
      expect(find.text('أني صاحب منشأة رياضية'), findsOneWidget);

      await tester.tap(find.text('أني لاعب'));
      await tester.pumpAndSettle();

      expect(UserService.instance.accountType, 'player');
      expect(find.byType(MainShell), findsOneWidget);
    });

    testWidgets('اختيار "أني صاحب منشأة رياضية" يفتح الحساب المنفصل', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const AccountTypeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أني صاحب منشأة رياضية'));
      await tester.pumpAndSettle();

      expect(UserService.instance.accountType, 'owner');
      expect(find.byType(OwnerShell), findsOneWidget);
      expect(find.text('لوحة التحكم'), findsWidgets);
      expect(find.text('منشآتي'), findsWidgets);
    });
  });

  group('حساب صاحب المنشأة المنفصل', () {
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

    testWidgets('لوحة التحكم تظهر منشآت المالك، وباقي التبويبات تفتح', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const OwnerShell()));
      await tester.pumpAndSettle();

      // لوحة التحكم (التبويب الافتراضي) — منشآت mock-user تظهر
      expect(find.text('أرباح اليوم'), findsOneWidget);
      expect(find.text('ملعب النجوم'), findsWidgets);

      // تبويب منشآتي
      await tester.tap(find.text('منشآتي').last);
      await tester.pumpAndSettle();
      expect(find.text('ملعب النجوم'), findsWidgets);
      expect(find.text('أضف منشأة'), findsWidgets);

      // تبويب الحجوزات
      await tester.tap(find.text('الحجوزات').last);
      await tester.pumpAndSettle();
      expect(find.text('القادمة'), findsOneWidget);
      expect(find.text('السابقة'), findsOneWidget);

      // تبويب الإعدادات
      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();
      expect(find.text('منشآتي'), findsWidgets);
      expect(find.text('تسجيل خروج'), findsOneWidget);
    });

    testWidgets('إضافة منشأة جديدة من تبويب منشآتي تظهر بالقائمة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const OwnerShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('منشآتي').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('أضف منشأة').first);
      await tester.pumpAndSettle();
      expect(find.byType(AddVenueScreen), findsOneWidget);

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'ملعبي التجريبي');
      await tester.enterText(textFields.at(1), 'المنطقة');
      await tester.enterText(textFields.at(2), 'بغداد');
      await tester.enterText(textFields.at(3), '18000');
      await tester.enterText(textFields.at(4), '07701112233');

      await tester.tap(find.text('أضف المنشأة'));
      await tester.pumpAndSettle();

      expect(find.byType(AddVenueScreen), findsNothing);
      expect(find.text('ملعبي التجريبي'), findsWidgets);
    });
  });

  group('تبديل نوع الحساب', () {
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

    testWidgets('من إعدادات اللاعب: الإلغاء ما يغيّر شي، والتأكيد يفتح حساب صاحب منشأة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await UserService.instance.saveAccountType('player');
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('صير صاحب منشأة'));
      await tester.pumpAndSettle();
      expect(find.text('تصير صاحب منشأة؟'), findsOneWidget);

      // الإلغاء ما يبدّل شي
      await tester.tap(find.text('لا، خليه'));
      await tester.pumpAndSettle();
      expect(UserService.instance.accountType, 'player');
      expect(find.byType(OwnerShell), findsNothing);

      // التأكيد يبدّل فعلاً ويفتح الحساب المنفصل
      await tester.tap(find.text('صير صاحب منشأة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إي، أكيد'));
      await tester.pumpAndSettle();

      expect(UserService.instance.accountType, 'owner');
      expect(find.byType(OwnerShell), findsOneWidget);
    });

    testWidgets('من إعدادات صاحب المنشأة: الرجوع للاعب ما يفقد منشآته', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await UserService.instance.saveAccountType('owner');
      final before = await fields.myFields('mock-user');
      expect(before, isNotEmpty);

      await tester.pumpWidget(app(const OwnerShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الإعدادات').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('ارجع لاعب'));
      await tester.pumpAndSettle();
      expect(find.text('ترجع لاعب؟'), findsOneWidget);
      await tester.tap(find.text('إي، أكيد'));
      await tester.pumpAndSettle();

      expect(UserService.instance.accountType, 'player');
      expect(find.byType(MainShell), findsOneWidget);

      // منشآته تبقى محفوظة رغم رجوعه لاعب
      final after = await fields.myFields('mock-user');
      expect(after.length, before.length);
    });
  });
}
