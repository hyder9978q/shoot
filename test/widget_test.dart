import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoot/core/utils/date_labels.dart';
import 'package:shoot/features/bookings/screens/bookings_tab.dart';
import 'package:shoot/features/home/widgets/play_now_section.dart';
import 'package:shoot/features/players/screens/new_request_screen.dart';
import 'package:shoot/features/profile/screens/favorites_screen.dart';
import 'package:shoot/main.dart';

void main() {
  testWidgets('رحلة كاملة: سبلاش → دخول → الملاعب → حجز ناجح',
      (WidgetTester tester) async {
    // شاشة موبايل طويلة حتى كل العناصر تبين بدون تمرير
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // نخفي قسم "العب اليوم" بهاي الرحلة حتى ما تتكرر أسماء الملاعب
    // (القسم إله اختبار مستقل بـ play_now_test.dart)
    PlayNowSection.debugNowHour = 24;
    addTearDown(() => PlayNowSection.debugNowHour = null);

    // نثبت الوقت الظهر حتى حجز الساعة 17:00 يظل "قادم" مهما كان
    // وقت تشغيل الاختبار (بدون التثبيت يفشل إذا انشغّل بعد الـ 6 مساءً)
    DateLabels.debugNow = DateTime(2026, 7, 15, 12);
    addTearDown(() => DateLabels.debugNow = null);

    await tester.pumpWidget(const ShootApp());

    // شاشة السبلاش تعرض الاسم والشعار
    expect(find.text('شوت'), findsOneWidget);
    expect(find.text('شوت... واحجز ملعبك.'), findsOneWidget);

    // بعد ثانيتين ونص ننتقل لتسجيل الدخول
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('هلا بيك بشوت 👋'), findsOneWidget);

    // رقم غلط → رسالة خطأ
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('دزلي الرمز'));
    await tester.pump();
    expect(find.text('الرقم لازم يبدي بـ 07 ويكون 11 رقم'), findsOneWidget);

    // رقم صحيح → شاشة الرمز
    await tester.enterText(find.byType(TextField), '07701234567');
    await tester.tap(find.text('دزلي الرمز'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('دخّل رمز التحقق'), findsOneWidget);

    // الرمز الصحيح → شاشة الاسم (أول تسجيل)
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('تأكيد'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('شنو نسميك؟ 😊'), findsOneWidget);

    // ندخل الاسم → الرئيسية بتحية شخصية
    await tester.enterText(find.byType(TextField), 'حيدر');
    await tester.tap(find.text('يلا نبدي'));
    await tester.pumpAndSettle();
    expect(find.text('هلا بيك، حيدر 👋'), findsOneWidget);
    expect(find.text('ملعب النجوم'), findsOneWidget);

    // إضافة ملعب النجوم للمفضلة من بطاقته
    await tester.tap(find.byKey(const Key('fav-f1')));
    await tester.pump();

    // بانر اللعبة موجود ويفتح لعبة ضربات الترجيح
    expect(find.text('جرّب حظك بضربات الترجيح'), findsOneWidget);
    await tester.tap(find.text('العب هسه'));
    await tester.pumpAndSettle();
    expect(find.text('اضغط على مكان بالمرمى وسدد ⚽'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('هلا بيك، حيدر 👋'), findsOneWidget);

    // البحث يفلتر
    await tester.enterText(find.byType(TextField), 'بادل');
    await tester.pump();
    expect(find.text('بادل هاوس'), findsOneWidget);
    expect(find.text('ملعب النجوم'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // خريطة الملاعب: دبوس بادل هاوس → بطاقة → تفاصيل
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();
    // العنوان يعرض عدد الملاعب على الخريطة
    expect(find.textContaining('خريطة الملاعب'), findsOneWidget);
    // شريط المدن يتولد من البيانات (كل العراق + بغداد + البصرة + أربيل)
    expect(find.text('كل العراق'), findsOneWidget);
    expect(find.text('بغداد'), findsOneWidget);

    // ننقل للبصرة ثم نضغط دبوس ملعبها
    await tester.tap(find.text('البصرة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pin-f7')));
    await tester.pumpAndSettle();
    expect(find.text('ملعب شط العرب'), findsWidgets);
    await tester.tap(find.text('شوف واحجز'));
    await tester.pumpAndSettle();
    expect(find.text('اختار اليوم والوقت'), findsOneWidget);
    // رجوع من التفاصيل (زر التصميم الجديد) ثم من الخريطة
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new).first);
    await tester.pumpAndSettle();
    expect(find.text('هلا بيك، حيدر 👋'), findsOneWidget);

    // فلتر المدينة: البصرة تعرض ملعب شط العرب فقط
    await tester.tap(find.text('كل العراق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البصرة'));
    await tester.pumpAndSettle();
    expect(find.text('ملعب شط العرب'), findsOneWidget);
    expect(find.text('ملعب النجوم'), findsNothing);
    await tester.tap(find.text('البصرة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كل العراق').last);
    await tester.pumpAndSettle();
    expect(find.text('ملعب النجوم'), findsOneWidget);

    // فتح تفاصيل الملعب
    await tester.tap(find.text('ملعب النجوم'));
    await tester.pumpAndSettle();
    expect(find.text('اختار اليوم والوقت'), findsOneWidget);

    // الوصف والمرافق ظاهرين
    expect(find.text('عن الملعب'), findsOneWidget);
    expect(find.text('المرافق'), findsOneWidget);
    expect(find.text('إضاءة ليلية'), findsOneWidget);

    // التقييمات: التجريبية موجودة، وننشر تقييمنا
    await tester.ensureVisible(find.text('التقييمات (٢)'));
    expect(find.text('مصطفى'), findsOneWidget);
    await tester.tap(find.text('قيّم الملعب'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).last,
      'ملعب نظيف وتجربة حلوة',
    );
    await tester.tap(find.text('انشر التقييم'));
    await tester.pumpAndSettle();
    expect(find.text('التقييمات (٣)'), findsOneWidget);
    expect(find.text('ملعب نظيف وتجربة حلوة'), findsOneWidget);
    expect(find.text('عدّل تقييمك'), findsOneWidget);
    // ننتظر رسالة "تم حفظ تقييمك" تختفي حتى ما تغطي الأزرار بعدين
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('اختار اليوم والوقت'));

    // بالتصميم الجديد: الوقت المحجوز يبين مشطوب (بدل كلمة "محجوز")
    bool isBookedSlot(String hour) {
      final text = tester.widget<Text>(find.text(hour));
      return text.style?.decoration == TextDecoration.lineThrough;
    }

    // اختيار الأيام: باچر كل الأوقات فاضية، واليوم بيها محجوزات
    expect(find.text('اليوم'), findsOneWidget);
    expect(find.text('باچر'), findsOneWidget);
    expect(isBookedSlot('18:00'), isTrue);
    await tester.tap(find.text('باچر'));
    await tester.pumpAndSettle();
    expect(isBookedSlot('18:00'), isFalse);
    await tester.tap(find.text('اليوم'));
    await tester.pumpAndSettle();
    expect(isBookedSlot('18:00'), isTrue);

    // اختيار وقت متاح والحجز
    await tester.tap(find.text('17:00'));
    await tester.pump();
    await tester.tap(find.text('احجز هسه'));
    await tester.pumpAndSettle();

    // شاشة تأكيد الحجز والدفع: ملخص + طريقة دفع + زر العربون
    expect(find.text('تأكيد الحجز'), findsOneWidget);
    expect(find.text('ملخص الحجز'), findsOneWidget);
    expect(find.text('زين كاش'), findsOneWidget);
    await tester.tap(find.text('ادفع العربون ٥٬٠٠٠ د.ع'));
    await tester.pumpAndSettle();
    expect(find.text('تم الحجز ✅'), findsOneWidget);

    // الرجوع للرئيسية
    await tester.tap(find.text('ارجع للرئيسية'));
    await tester.pumpAndSettle();
    expect(find.text('هلا بيك، حيدر 👋'), findsOneWidget);

    // تبويب حجوزاتي: الحجز الجديد موجود
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('حجوزاتي'),
    ));
    await tester.pumpAndSettle();
    Finder inBookingsTab(Finder f) =>
        find.descendant(of: find.byType(BookingsTab), matching: f);
    expect(inBookingsTab(find.text('ملعب النجوم')), findsOneWidget);
    expect(inBookingsTab(find.text('مؤكد')), findsOneWidget);
    // البطاقة الجديدة تعرض: اليوم · الساعة
    expect(inBookingsTab(find.text('اليوم · 17:00')), findsOneWidget);
    expect(inBookingsTab(find.text('القادمة')), findsOneWidget);

    // إلغاء الحجز → القائمة تفرغ
    await tester.tap(find.text('إلغاء الحجز'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إي، الغيه'));
    await tester.pumpAndSettle();
    expect(inBookingsTab(find.text('بعدك ما عندك حجوزات')), findsOneWidget);

    // تبويب ناقصنا لاعب: الإعلانات التجريبية موجودة
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('ناقصنا لاعب'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ناقصهم لاعب واحد'), findsOneWidget);
    expect(find.text('ناقصهم 2 لاعبين'), findsOneWidget);

    // نشر إعلان جديد
    await tester.tap(find.widgetWithText(ElevatedButton, 'انشر إعلان').first);
    await tester.pumpAndSettle();
    Finder inForm(Finder f) =>
        find.descendant(of: find.byType(NewRequestScreen), matching: f);
    await tester.enterText(
      inForm(find.byType(TextField)).first,
      'ملعب الأبطال — زيونة',
    );
    await tester.ensureVisible(inForm(find.text('21:00')));
    await tester.tap(inForm(find.text('21:00')));
    await tester.pump();
    await tester.ensureVisible(inForm(find.byIcon(Icons.add_rounded)));
    await tester.tap(inForm(find.byIcon(Icons.add_rounded)));
    await tester.pump();
    await tester.tap(inForm(find.widgetWithText(ElevatedButton, 'انشر إعلان')));
    await tester.pumpAndSettle();

    // الإعلان الجديد ظهر بالقائمة وعليه شارة "إعلانك"
    expect(find.text('ملعب الأبطال — زيونة'), findsOneWidget);
    expect(find.text('إعلانك'), findsOneWidget);

    // ننتظر رسالة "انتشر إعلانك" تختفي حتى ما تغطي زر الحذف
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // حذف الإعلان بعد اكتمال الفريق
    await tester.ensureVisible(find.text('حذف الإعلان'));
    await tester.tap(find.text('حذف الإعلان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إي، احذفه'));
    await tester.pumpAndSettle();
    expect(find.text('إعلانك'), findsNothing);

    // تبويب حسابي: المستخدم التجريبي صاحب ملعب → اللوحة تظهرله
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('حسابي'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لوحة صاحب الملعب'));
    await tester.pumpAndSettle();
    expect(find.text('ملعب النجوم'), findsWidgets);
    expect(find.text('أرباح اليوم'), findsOneWidget);
    expect(find.text('حجوزات اليوم'), findsOneWidget);
    expect(find.text('أرباح الأسبوع'), findsOneWidget);
    // بالوضع التجريبي: الساعات 18 و21 محجوزة (نمط h%3==0)
    expect(find.text('محجوز'), findsWidgets);
    expect(find.text('فاضي'), findsWidgets);

    // رجوع من اللوحة → المفضلة: ملعب النجوم موجود
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المفضلة'));
    await tester.pumpAndSettle();
    Finder inFavorites(Finder f) =>
        find.descendant(of: find.byType(FavoritesScreen), matching: f);
    expect(inFavorites(find.text('ملعب النجوم')), findsOneWidget);

    // إزالة القلب → المفضلة تفرغ
    await tester.tap(inFavorites(find.byKey(const Key('fav-f1'))));
    await tester.pumpAndSettle();
    expect(inFavorites(find.text('بعدك ماكو مفضلة')), findsOneWidget);

    // تقييماتي: تقييمنا موجود، ونحذفه
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تقييماتي'));
    await tester.pumpAndSettle();
    expect(find.text('ملعب نظيف وتجربة حلوة'), findsOneWidget);
    await tester.tap(find.text('حذف التقييم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إي، احذفه'));
    await tester.pumpAndSettle();
    expect(find.text('بعدك ما قيّمت أي ملعب'), findsOneWidget);
  });
}
