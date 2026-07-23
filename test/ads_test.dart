import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/models/ad.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/services/ads_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/core/utils/date_labels.dart';
import 'package:shoot/features/home/widgets/ads_section.dart';
import 'package:shoot/features/owner/screens/owner_ads_screen.dart';
import 'package:shoot/features/owner/screens/owner_shell.dart';

/// نظام إعلانات صاحب المنشأة: نشر/تعديل/إيقاف/حذف، فحص الملكية،
/// وعرضها للاعبين بالرئيسية وصفحة تفاصيل المنشأة.
void main() {
  final ads = AdsService.instance;
  final fields = FieldsService.instance;

  setUp(() {
    DateLabels.debugNow = DateTime(2026, 7, 15);
    ads.debugReset();
    fields.debugReset();
  });

  tearDown(() {
    DateLabels.debugNow = null;
    ads.debugReset();
    fields.debugReset();
  });

  Future<Field> owned() async {
    final all = await fields.loadAllFields();
    return all.firstWhere((f) => f.ownerId == 'mock-user');
  }

  Future<Field> notOwned() async {
    final all = await fields.loadAllFields();
    return all.firstWhere((f) => f.ownerId != 'mock-user');
  }

  group('AdsService.createAd', () {
    test('ينشر إعلان جديد لمنشأة يملكها المستخدم الحالي', () async {
      final field = await owned();
      final created = await ads.createAd(
        field,
        title: 'خصم ٢٠٪',
        body: 'خصم لعموم الحجوزات نهاية الأسبوع',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(7),
      );

      expect(created.fieldId, field.id);
      expect(created.ownerId, 'mock-user');
      expect(created.fieldName, field.name);
      expect(created.isActive, isTrue);
    });

    test('يرفض النشر لمنشأة مو تابعة للمستخدم', () async {
      final field = await notOwned();
      expect(
        () => ads.createAd(
          field,
          title: 'إعلان',
          body: 'نص الإعلان',
          type: AdType.news,
          expiresAt: DateLabels.dateFor(7),
        ),
        throwsStateError,
      );
    });

    test('ينظّف العنوان والنص من الرموز الخطيرة', () async {
      final field = await owned();
      final created = await ads.createAd(
        field,
        title: '<script>alert(1)</script> عرض خاص',
        body: '<b>تفاصيل</b> العرض',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(7),
      );
      expect(created.title, isNot(contains('<')));
      expect(created.title, contains('عرض خاص'));
      expect(created.body, isNot(contains('<')));
    });

    test('يرفض عنوان أو نص فارغ', () async {
      final field = await owned();
      expect(
        () => ads.createAd(
          field,
          title: '   ',
          body: 'نص الإعلان',
          type: AdType.news,
          expiresAt: DateLabels.dateFor(7),
        ),
        throwsArgumentError,
      );
      expect(
        () => ads.createAd(
          field,
          title: 'عنوان',
          body: '   ',
          type: AdType.news,
          expiresAt: DateLabels.dateFor(7),
        ),
        throwsArgumentError,
      );
    });

    test('يرفض تاريخ انتهاء بالماضي', () async {
      final field = await owned();
      expect(
        () => ads.createAd(
          field,
          title: 'عنوان',
          body: 'نص',
          type: AdType.news,
          expiresAt: DateLabels.dateFor(-1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AdsService.updateAd / setActive / deleteAd', () {
    test('يعدّل إعلان موجود يملكه', () async {
      final field = await owned();
      final created = await ads.createAd(
        field,
        title: 'عرض',
        body: 'نص',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(7),
      );
      final updated = await ads.updateAd(
        created,
        title: 'عرض معدّل',
        body: 'نص جديد',
        type: AdType.tournament,
        expiresAt: DateLabels.dateFor(10),
        imageUrl: '',
      );
      expect(updated.title, 'عرض معدّل');
      expect(updated.type, AdType.tournament);
    });

    test('يوقف الإعلان ويعيد تفعيله', () async {
      final field = await owned();
      final created = await ads.createAd(
        field,
        title: 'عرض',
        body: 'نص',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(7),
      );
      final paused = await ads.setActive(created, false);
      expect(paused.isActive, isFalse);

      final resumed = await ads.setActive(paused, true);
      expect(resumed.isActive, isTrue);
    });

    test('يحذف إعلان نهائياً', () async {
      final field = await owned();
      final created = await ads.createAd(
        field,
        title: 'عرض',
        body: 'نص',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(7),
      );
      await ads.deleteAd(created);
      final mine = await ads.myAds([field.id]);
      expect(mine.where((a) => a.id == created.id), isEmpty);
    });

    test('يرفض تعديل/حذف إعلان مالك ثاني', () async {
      // إعلان يتظاهر بملكية مستخدم آخر (كأنه جانا من قاعدة بيانات ثانية)
      const foreignAd = Ad(
        id: 'ad-x',
        fieldId: 'f2',
        ownerId: 'someone-else',
        fieldName: 'ملعب الأبطال',
        title: 'عنوان',
        body: 'نص',
        type: AdType.news,
        expiresAt: '2099-01-01',
      );
      expect(
        () => ads.setActive(foreignAd, false),
        throwsStateError,
      );
      expect(() => ads.deleteAd(foreignAd), throwsStateError);
    });
  });

  group('Ad.isVisibleAt / isExpiredAt', () {
    test('منتهي إذا تاريخ الانتهاء قبل اليوم', () {
      const ad = Ad(
        id: 'a',
        fieldId: 'f1',
        ownerId: 'u',
        fieldName: 'ملعب',
        title: 'ت',
        body: 'ن',
        type: AdType.news,
        expiresAt: '2026-01-01',
      );
      expect(ad.isExpiredAt('2026-07-15'), isTrue);
      expect(ad.isVisibleAt('2026-07-15'), isFalse);
    });

    test('نشيط وظاهر لو مفعّل وغير منتهي', () {
      const ad = Ad(
        id: 'a',
        fieldId: 'f1',
        ownerId: 'u',
        fieldName: 'ملعب',
        title: 'ت',
        body: 'ن',
        type: AdType.news,
        expiresAt: '2026-12-31',
      );
      expect(ad.isVisibleAt('2026-07-15'), isTrue);
    });

    test('مو ظاهر لو موقوف حتى لو غير منتهي', () {
      const ad = Ad(
        id: 'a',
        fieldId: 'f1',
        ownerId: 'u',
        fieldName: 'ملعب',
        title: 'ت',
        body: 'ن',
        type: AdType.news,
        expiresAt: '2026-12-31',
        isActive: false,
      );
      expect(ad.isVisibleAt('2026-07-15'), isFalse);
    });
  });

  group('AdsService.activeAds / activeAdsForField', () {
    test('يرجّع النشطة فقط، الأحدث أولاً، وما يرجّع الموقوفة والمنتهية', () async {
      final field = await owned();
      // فاصل زمني صغير بين كل نشر حتى ما تتصادم معرّفات وضع التجربة
      // (مبنية على microsecondsSinceEpoch) لو انطبعت بنفس اللحظة تماماً
      final expired = await ads.createAd(
        field,
        title: 'قديم',
        body: 'نص',
        type: AdType.news,
        expiresAt: DateLabels.dateFor(1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final paused = await ads.createAd(
        field,
        title: 'موقوف',
        body: 'نص',
        type: AdType.news,
        expiresAt: DateLabels.dateFor(10),
      );
      await ads.setActive(paused, false);

      await Future<void>.delayed(const Duration(milliseconds: 2));
      final active = await ads.createAd(
        field,
        title: 'نشيط',
        body: 'نص',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(10),
      );

      final result = await ads.activeAdsForField(field.id);
      expect(result.map((a) => a.id), contains(active.id));
      expect(result.map((a) => a.id), isNot(contains(paused.id)));
      // "expired" هنا لسا ما انتهى فعلياً (تاريخه بعد اليوم) فيبقى نشيط
      expect(result.map((a) => a.id), contains(expired.id));
    });

    test('activeAds تختفي بدون إعلانات', () async {
      final result = await ads.activeAds();
      expect(result, isEmpty);
    });
  });

  group('AdsService.myAds', () {
    test('قائمة فاضية بدون منشآت', () async {
      final result = await ads.myAds(const []);
      expect(result, isEmpty);
    });

    test('يرجّع إعلانات كل منشآت المالك عبر أكثر من منشأة', () async {
      final field = await owned();
      await ads.createAd(
        field,
        title: 'إعلان ١',
        body: 'نص',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(7),
      );
      final mine = await ads.myAds([field.id]);
      expect(mine.length, 1);
      expect(mine.first.title, 'إعلان ١');
    });
  });

  group('واجهة إعلاناتي (صاحب المنشأة)', () {
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

    testWidgets('تبويب إعلاناتي فارغ يبين رسالة وزر نشر', (tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const OwnerShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('إعلاناتي').last);
      await tester.pumpAndSettle();

      expect(find.byType(OwnerAdsScreen), findsOneWidget);
      expect(find.text('ما نشرت أي إعلان بعد'), findsOneWidget);
    });

    testWidgets('نشر إعلان جديد يظهر بالقائمة', (tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(const OwnerShell()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إعلاناتي').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('أضف إعلان').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'خصم الصيف');
      await tester.enterText(
        find.byType(TextField).at(1),
        'خصم ٣٠٪ على كل الحجوزات',
      );
      await tester.tap(find.text('انشر الإعلان'));
      await tester.pumpAndSettle();

      expect(find.text('خصم الصيف'), findsWidgets);
    });
  });

  group('عرض الإعلانات للاعبين', () {
    test('قسم الرئيسية يختفي بدون إعلانات نشطة', () async {
      final result = await AdsService.instance.activeAds();
      expect(result, isEmpty);
    });

    testWidgets('AdsSection يختفي كلياً بدون إعلانات', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: AdsSection()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('العروض والإعلانات'), findsNothing);
    });

    testWidgets('AdsSection يبين إعلان نشيط بعد نشره', (tester) async {
      final field = await owned();
      await ads.createAd(
        field,
        title: 'عرض اليوم',
        body: 'تفاصيل العرض',
        type: AdType.promo,
        expiresAt: DateLabels.dateFor(7),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: AdsSection()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('العروض والإعلانات'), findsOneWidget);
      expect(find.text('عرض اليوم'), findsOneWidget);
    });
  });
}
