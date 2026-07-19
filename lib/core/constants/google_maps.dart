/// إعدادات Google Maps / Places.
///
/// المفتاح ما ينحفظ بالكود — ينمرر وقت البناء:
///   flutter run --dart-define=GOOGLE_MAPS_KEY=AIza...
///   flutter build web --dart-define=GOOGLE_MAPS_KEY=AIza...
/// وبـ Vercel ينحط كمتغير بيئة ويندمج بأمر البناء.
///
/// المفتاح المستعمل بالتطبيق لازم يكون **مقيّد بالتطبيق** (اسم الحزمة + SHA
/// للأندرويد، ونطاق الموقع للويب) ومحصور بـ Places API — مو نفس المفتاح
/// المقيّد بـ IP الخادم اللي نستعمله بسكربت السحب.
class GoogleMaps {
  const GoogleMaps._();

  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

  static bool get hasKey => apiKey.isNotEmpty;

  /// رابط صورة من Places Photos — فارغ إذا ما بيه مرجع صورة أو ما بيه مفتاح،
  /// وعندها التطبيق يرجع للرسمة المرسومة بدل ما ينكسر.
  static String photoUrl(String photoName, {int maxWidthPx = 800}) {
    if (photoName.isEmpty || !hasKey) return '';
    return 'https://places.googleapis.com/v1/$photoName/media'
        '?maxWidthPx=$maxWidthPx&key=$apiKey';
  }
}
