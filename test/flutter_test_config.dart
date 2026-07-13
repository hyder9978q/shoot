import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// إعداد الاختبارات — يحمّل خط Cairo وأيقونات Material
/// حتى تطلع لقطات الشاشة (goldens) بنصوص وأيقونات حقيقية.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cairo = FontLoader('Cairo');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    cairo.addFont(_load('assets/fonts/Cairo-$weight.ttf'));
  }
  await cairo.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final iconsPath =
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(iconsPath).existsSync()) {
      final icons = FontLoader('MaterialIcons')..addFont(_load(iconsPath));
      await icons.load();
    }
  }

  await testMain();
}

Future<ByteData> _load(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(bytes.buffer);
}
