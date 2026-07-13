import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/widgets/shoot_logo.dart';

/// مولّد أيقونة التطبيق — يرسم الشعار ويصدّره PNG بدقة 1024×1024.
///
/// التحديث:
///   flutter test test/tools/app_icon_test.dart --update-goldens
///   dart run flutter_launcher_icons
void main() {
  Future<void> render(
    WidgetTester tester,
    Widget icon,
    String fileName,
  ) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(child: icon),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('../../assets/icon/$fileName'),
    );
  }

  testWidgets('توليد الأيقونة الرئيسية', (tester) async {
    await render(tester, const ShootAppIcon(), 'app_icon.png');
  });

  testWidgets('توليد الطبقة الأمامية للأيقونة التكيفية', (tester) async {
    await render(
      tester,
      const ShootAppIcon(transparentBackground: true, contentScale: 0.6),
      'app_icon_foreground.png',
    );
  });
}
