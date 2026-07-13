import 'package:flutter/material.dart';

/// مرافق الملعب — تنخزن كمفاتيح نصية بـ Firestore
enum Amenity {
  parking('مواقف سيارات', Icons.local_parking_rounded),
  lights('إضاءة ليلية', Icons.light_mode_rounded),
  water('ماء ومرطبات', Icons.water_drop_rounded),
  changing('غرف تبديل', Icons.checkroom_rounded),
  cafeteria('كافتيريا', Icons.local_cafe_rounded),
  wifi('واي فاي', Icons.wifi_rounded);

  const Amenity(this.label, this.icon);

  final String label;
  final IconData icon;

  /// تحويل مفاتيح نصية من قاعدة البيانات مع تجاهل المجهول
  static List<Amenity> fromKeys(List<dynamic>? keys) {
    if (keys == null) return const [];
    return [
      for (final key in keys)
        for (final a in Amenity.values)
          if (a.name == key) a,
    ];
  }
}

/// أنواع الرياضات المدعومة
enum Sport {
  football('كرة قدم', Icons.sports_soccer),
  padel('بادل', Icons.sports_tennis),
  basketball('سلة', Icons.sports_basketball),
  tennis('تنس', Icons.sports_baseball);

  const Sport(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// موديل الملعب — نفس الحقول راح تنخزن بـ Firestore لاحقاً
class Field {
  const Field({
    required this.id,
    required this.name,
    required this.area,
    required this.city,
    required this.sport,
    required this.pricePerHour,
    required this.rating,
    required this.reviewsCount,
    this.openHour = 16,
    this.closeHour = 24,
    this.ownerId = '',
    this.imageUrl = '',
    this.description = '',
    this.amenities = const [],
    this.lat = 0,
    this.lng = 0,
    this.surfaceType = '',
    this.sizeLabel = '',
  });

  /// إنشاء ملعب من مستند Firestore
  factory Field.fromMap(String id, Map<String, dynamic> data) {
    return Field(
      id: id,
      name: (data['name'] as String?) ?? '',
      area: (data['area'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      sport: Sport.values.firstWhere(
        (s) => s.name == data['sport'],
        orElse: () => Sport.football,
      ),
      pricePerHour: (data['pricePerHour'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: (data['reviewsCount'] as num?)?.toInt() ?? 0,
      openHour: (data['openHour'] as num?)?.toInt() ?? 16,
      closeHour: (data['closeHour'] as num?)?.toInt() ?? 24,
      ownerId: (data['ownerId'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      amenities: Amenity.fromKeys(data['amenities'] as List?),
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      surfaceType: (data['surfaceType'] as String?) ?? '',
      sizeLabel: (data['sizeLabel'] as String?) ?? '',
    );
  }

  final String id;
  final String name;

  /// المنطقة (مثال: المنصور)
  final String area;

  /// المدينة (مثال: بغداد)
  final String city;
  final Sport sport;

  /// السعر بالدينار العراقي للساعة
  final int pricePerHour;
  final double rating;
  final int reviewsCount;

  /// ساعات الدوام (24 = منتصف الليل)
  final int openHour;
  final int closeHour;

  /// معرّف صاحب الملعب — فارغ إذا الملعب بعده بدون مالك بالتطبيق
  final String ownerId;

  /// رابط صورة الملعب — فارغ = تنعرض رسمة الملعب المرسومة
  final String imageUrl;

  /// نبذة عن الملعب (اختيارية)
  final String description;

  /// المرافق المتوفرة
  final List<Amenity> amenities;

  /// إحداثيات الملعب على الخريطة (0 = ما محددة)
  final double lat;
  final double lng;

  /// نوع الأرضية والحجم (فارغ = افتراضي حسب الرياضة)
  final String surfaceType;
  final String sizeLabel;

  bool get hasLocation => lat != 0 && lng != 0;

  /// نوع الأرضية — إذا مو مخزّن ننطي افتراضي حسب الرياضة
  String get surfaceLabel {
    if (surfaceType.isNotEmpty) return surfaceType;
    return switch (sport) {
      Sport.football => 'عشب صناعي',
      Sport.basketball => 'باركيه',
      Sport.tennis => 'أرضية صلبة',
      Sport.padel => 'زجاج وعشب',
    };
  }

  /// حجم الملعب — افتراضي حسب الرياضة
  String get sizeText {
    if (sizeLabel.isNotEmpty) return sizeLabel;
    return switch (sport) {
      Sport.football => '٧ × ٧',
      Sport.basketball => '٥ × ٥',
      Sport.tennis => 'فردي/زوجي',
      Sport.padel => '٢ × ٢',
    };
  }

  /// نص الإضاءة حسب المرافق
  String get lightingLabel =>
      amenities.contains(Amenity.lights) ? 'ليلي' : 'نهاري';

  String get location => '$area، $city';
}

/// وقت متاح للحجز
class TimeSlot {
  const TimeSlot({required this.hour, required this.isBooked});

  /// ساعة البداية (مثال: 17 يعني من 5 لـ 6 مساءً)
  final int hour;
  final bool isBooked;

  String get label {
    final start = hour.toString().padLeft(2, '0');
    final end = (hour + 1).toString().padLeft(2, '0');
    return '$start:00 - $end:00';
  }
}
