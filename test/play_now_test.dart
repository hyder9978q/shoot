import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/services/bookings_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/features/home/widgets/play_now_section.dart';

void main() {
  testWidgets('قسم العب اليوم: يعرض أقرب وقت فاضي ويتحدث بعد الحجز',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // نثبت الساعة على 20 — بالوضع التجريبي الساعات المحجوزة هي 18 و21
    PlayNowSection.debugNowHour = 20;
    addTearDown(() => PlayNowSection.debugNowHour = null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(children: [PlayNowSection()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // العنوان ظاهر وأقرب وقت فاضي هو 20:00 (20 مو من مضاعفات 3)
    expect(find.text('العب اليوم'), findsOneWidget);
    expect(find.text('20:00'), findsWidgets);
    // الأعلى تقييماً يتصدر عند تساوي الوقت
    expect(find.text('بادل هاوس'), findsOneWidget);

    // نحجز الساعة 20 ببادل هاوس → وقته الأقرب يتأخر لـ 22:00
    // فيطلع من أفضل 6 (الكل عندهم 20:00) — القسم يتفاعل مع الحجز
    final padel =
        FieldsService.instance.search().firstWhere((f) => f.id == 'f3');
    final slots = await BookingsService.instance
        .slotsFor(padel, BookingsService.todayDate());
    await BookingsService.instance.createBooking(
      padel,
      slots.firstWhere((s) => s.hour == 20),
    );
    await tester.pumpAndSettle();

    expect(find.text('بادل هاوس'), findsNothing);
  });
}
