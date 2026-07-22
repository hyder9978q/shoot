import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/widgets/field_image.dart';
import 'package:shoot/core/widgets/field_visual.dart';

/// صورة الملعب المخزّنة مؤقتاً — لازم ما تكسر أي شاشة حتى بدون شبكة.
void main() {
  testWidgets('رابط فارغ → الرسمة المرسومة بدون أي طلب شبكة', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: FieldPhoto(sport: Sport.football, url: ''),
        ),
      ),
    );

    expect(find.byType(FieldVisual), findsOneWidget);
  });

  testWidgets('رابط موجود → ما ينهار ويبقى يعرض الرسمة تحت الصورة',
      (tester) async {
    // بالاختبارات ما بيه شبكة — المهم ما ينكسر ويبقى بديل معروض
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: FieldPhoto(
            sport: Sport.padel,
            url: 'https://example.com/field.jpg',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(FieldVisual), findsOneWidget);
  });
}
