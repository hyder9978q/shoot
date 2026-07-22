import 'dart:math' as math;

/// حسابات المسافة بين نقطتين على الخريطة
class Geo {
  Geo._();

  static const double _earthRadiusKm = 6371;

  /// المسافة بالكيلومتر بين نقطتين (هافرساين)
  static double distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return _earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double degrees) => degrees * math.pi / 180;

  /// نص المسافة بالعربي — "٨٠٠ متر" أو "٢٫٣ كم"
  static String label(double km) {
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters متر';
    }
    return '${km.toStringAsFixed(1)} كم';
  }
}
