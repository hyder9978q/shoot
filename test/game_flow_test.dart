import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/theme/app_theme.dart';
import 'package:shoot/features/game/logic/penalty_engine.dart';
import 'package:shoot/features/game/screens/game_screen.dart';

void main() {
  testWidgets('لعبة ضربات الترجيح: 5 ضربات → نتيجة → إعادة',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // بذرة ثابتة حتى يكون الاختبار قابل للتكرار
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: GameScreen(engine: PenaltyEngine(random: Random(7))),
        ),
      ),
    );

    // التلميح ظاهر ومناطق التسديد الست موجودة
    expect(find.text('اضغط على مكان بالمرمى وسدد ⚽'), findsOneWidget);
    for (final zone in GoalZone.values) {
      expect(find.byKey(Key('zone-${zone.name}')), findsOneWidget);
    }

    // نلعب 5 ضربات
    for (var shot = 0; shot < PenaltyEngine.shotsPerGame; shot++) {
      await tester.tap(find.byKey(const Key('zone-bottomLeft')));
      await tester.pump(const Duration(milliseconds: 500));
      // نص النتيجة ظاهر (گول / صدة / برا)
      final resultVisible = find.text('گوووول! ⚽').evaluate().isNotEmpty ||
          find.text('صدّها الحارس! 🧤').evaluate().isNotEmpty ||
          find.text('برا الحديدة! 😅').evaluate().isNotEmpty;
      expect(resultVisible, isTrue);
      // ننتظر الانتقال للضربة الجاية
      await tester.pump(const Duration(milliseconds: 1200));
    }

    // شاشة النتيجة النهائية
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('خلصت الجولة!'), findsOneWidget);
    expect(find.text('العب مرة ثانية'), findsOneWidget);
    expect(
      find.textContaining('قريباً: بدّل نقاطك بخصم'),
      findsOneWidget,
    );

    // إعادة اللعب ترجعنا لبداية جولة جديدة
    await tester.tap(find.text('العب مرة ثانية'));
    await tester.pump();
    expect(find.text('اضغط على مكان بالمرمى وسدد ⚽'), findsOneWidget);
    expect(find.text('خلصت الجولة!'), findsNothing);

    // الخروج من اللعبة (زر الإغلاق) ما يرمي أخطاء
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
  });
}
