import 'package:flutter/material.dart';

import '../constants/google_maps.dart';

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

/// فئات المنشآت المدعومة — ملاعب ومسابح وأندية ومراكز علاج
enum Sport {
  football('كرة قدم', Icons.sports_soccer),
  padel('بادل', Icons.sports_tennis),
  basketball('سلة', Icons.sports_basketball),
  tennis('تنس', Icons.sports_baseball),
  volleyball('كرة طائرة', Icons.sports_volleyball),
  swimming('مسبح', Icons.pool_rounded),
  gym('نادي رياضي', Icons.fitness_center_rounded),
  sportsCentre('مجمع رياضي', Icons.stadium_rounded),
  therapy('علاج رياضي', Icons.healing_rounded);

  const Sport(this.label, this.icon);

  final String label;
  final IconData icon;

  /// رياضة جماعية — بس هذي تنفع لطلبات اللاعبين (ما نطلب لاعبين لمسبح أو جم)
  bool get isTeamSport => switch (this) {
    Sport.football ||
    Sport.basketball ||
    Sport.volleyball ||
    Sport.padel ||
    Sport.tennis => true,
    Sport.swimming || Sport.gym || Sport.sportsCentre || Sport.therapy =>
      false,
  };

  /// حجز بالجلسة/الموعد بدل الحجز بالساعة (مراكز العلاج)
  bool get isSessionBased => this == Sport.therapy;
}

/// خدمة تقدّمها المنشأة (مراكز العلاج مثلاً) — اسم وسعر بالدينار
class VenueService {
  const VenueService({required this.name, required this.price});

  /// من خريطة Firestore — null إذا البيانات ناقصة أو خربانة
  static VenueService? fromMap(dynamic data) {
    if (data is! Map) return null;
    final name = data['name'];
    if (name is! String || name.isEmpty) return null;
    return VenueService(
      name: name,
      price: (data['price'] as num?)?.toInt() ?? 0,
    );
  }

  final String name;
  final int price;

  Map<String, Object> toMap() => {'name': name, 'price': price};
}

/// لقطة من الملعب (هايلايت) — صورة مرفوعة أو رابط فيديو (يوتيوب/انستغرام)
class FieldHighlight {
  const FieldHighlight({required this.url, required this.isVideo});

  /// من خريطة Firestore — null إذا البيانات ناقصة أو خربانة
  static FieldHighlight? fromMap(dynamic data) {
    if (data is! Map) return null;
    final url = data['url'];
    if (url is! String || url.isEmpty) return null;
    return FieldHighlight(url: url, isVideo: data['type'] == 'video');
  }

  final String url;

  /// true = رابط فيديو خارجي، false = صورة مرفوعة
  final bool isVideo;

  Map<String, String> toMap() => {
        'type': isVideo ? 'video' : 'image',
        'url': url,
      };
}

/// «منشأة» — الاسم العام لأي مكان بالتطبيق: ملعب، مسبح، مركز علاج...
/// نفس الموديل [Field] بكل ميزاته (حجز، صور، دفع، صلاحيات المالك).
typedef Venue = Field;

/// موديل المنشأة (تاريخياً «الملعب») — نفس الحقول تنخزن بـ Firestore.
/// الفئة تحددها [sport]: ملعب، مسبح، مركز علاج رياضي وطبيعي...
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
    this.imageUrls = const [],
    this.description = '',
    this.amenities = const [],
    this.lat = 0,
    this.lng = 0,
    this.surfaceType = '',
    this.sizeLabel = '',
    this.placeId = '',
    this.photoName = '',
    this.phone = '',
    this.isOpen = true,
    this.mapsUrl = '',
    this.promoImageUrls = const [],
    this.highlights = const [],
    this.paymentDeposit = true,
    this.paymentCashOnArrival = true,
    this.zainCashEnabled = false,
    this.zainCashMerchantId = '',
    this.services = const [],
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
      imageUrls: [
        for (final u in (data['imageUrls'] as List?) ?? const [])
          if (u is String && u.isNotEmpty) u,
      ],
      description: (data['description'] as String?) ?? '',
      amenities: Amenity.fromKeys(data['amenities'] as List?),
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      surfaceType: (data['surfaceType'] as String?) ?? '',
      sizeLabel: (data['sizeLabel'] as String?) ?? '',
      placeId: (data['placeId'] as String?) ?? '',
      photoName: (data['photoName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      isOpen: (data['isOpen'] as bool?) ?? true,
      mapsUrl: (data['mapsUrl'] as String?) ?? '',
      promoImageUrls: [
        for (final u in (data['promoImageUrls'] as List?) ?? const [])
          if (u is String && u.isNotEmpty) u,
      ],
      highlights: [
        for (final h in (data['highlights'] as List?) ?? const [])
          ?FieldHighlight.fromMap(h),
      ],
      paymentDeposit: (data['paymentDeposit'] as bool?) ?? true,
      paymentCashOnArrival: (data['paymentCashOnArrival'] as bool?) ?? true,
      zainCashEnabled: (data['zainCashEnabled'] as bool?) ?? false,
      zainCashMerchantId: (data['zainCashMerchantId'] as String?) ?? '',
      services: [
        for (final s in (data['services'] as List?) ?? const [])
          ?VenueService.fromMap(s),
      ],
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

  /// رابط صورة الملعب (قديم — صورة وحيدة) — فارغ = تنعرض رسمة الملعب المرسومة
  final String imageUrl;

  /// صور الملعب المتعددة اللي يرفعها المالك — أول وحدة هي الغلاف
  final List<String> imageUrls;

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

  /// معرّف المكان بخرائط Google — ثابت للأبد، منه نجدد بيانات المكان وصوره
  final String placeId;

  /// مرجع صورة Google (places/…/photos/…) — الصورة تنجلب وقت العرض،
  /// لأن ترخيص Google ما يسمح بتخزين الصورة نفسها عدنا
  final String photoName;

  /// رقم هاتف المكان (من خرائط Google) — للأماكن اللي بعدها ما مسجلة عدنا
  final String phone;

  /// حالة الملعب: مفتوح / مغلق مؤقتاً (يتحكم بيها المالك)
  final bool isOpen;

  /// رابط موقع الملعب على خرائط Google (يحطه المالك) — فارغ = نعتمد الإحداثيات
  final String mapsUrl;

  /// صور ترويجية (عروض/إعلانات) تظهر كبانر بصفحة الملعب
  final List<String> promoImageUrls;

  /// لقطات الملعب — صور أو روابط فيديو من مباريات انلعبت بالملعب
  final List<FieldHighlight> highlights;

  /// طرق الدفع المقبولة بالملعب (يتحكم بيها المالك)
  final bool paymentDeposit;
  final bool paymentCashOnArrival;

  /// بوابة زين كاش — واجهة فقط، التفعيل الفعلي بعده ما مربوط
  final bool zainCashEnabled;
  final String zainCashMerchantId;

  /// الخدمات المقدّمة وأسعارها (لمراكز العلاج خصوصاً) — يديرها المالك
  final List<VenueService> services;

  bool get hasLocation => lat != 0 && lng != 0;

  /// رابط الموقع اللي ينفتح من صفحة الملعب: رابط المالك أولاً، ثم الإحداثيات
  String get locationUrl {
    if (mapsUrl.isNotEmpty) return mapsUrl;
    if (!hasLocation) return '';
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  /// ينحجز بالتطبيق؟ الأماكن المسحوبة من الخرائط ما عدها سعر ولا مالك،
  /// فتنعرض للاكتشاف والاتصال بس، لحد ما صاحبها يسجّل ويحدد سعره.
  bool get isBookable => pricePerHour > 0;

  /// كل صور الملعب المتوفرة بالترتيب: صور المالك المرفوعة أولاً (الأهم)،
  /// ثم الصورة المفردة القديمة، ثم صورة Google. القائمة تنظّف الفراغات والمكرر.
  /// فارغة = ما بيه صور حقيقية، تنعرض الرسمة المرسومة.
  List<String> get galleryImages {
    final all = <String>[
      ...imageUrls,
      if (imageUrl.isNotEmpty) imageUrl,
      GoogleMaps.photoUrl(photoName),
    ];
    final seen = <String>{};
    return [
      for (final u in all)
        if (u.isNotEmpty && seen.add(u)) u,
    ];
  }

  /// رابط صورة الغلاف بالبطاقة — أول صورة متوفرة.
  /// فارغ = ما بيه صورة، تنعرض الرسمة المرسومة.
  String get displayImageUrl {
    final images = galleryImages;
    return images.isEmpty ? '' : images.first;
  }

  /// نسخة معدّلة — تُستخدم بعد أي تعديل من المالك لتحديث الواجهة فوراً
  Field copyWith({
    String? name,
    String? area,
    String? city,
    Sport? sport,
    int? pricePerHour,
    int? openHour,
    int? closeHour,
    List<String>? imageUrls,
    bool? isOpen,
    String? mapsUrl,
    List<String>? promoImageUrls,
    List<FieldHighlight>? highlights,
    bool? paymentDeposit,
    bool? paymentCashOnArrival,
    bool? zainCashEnabled,
    String? zainCashMerchantId,
    List<VenueService>? services,
  }) {
    return Field(
      id: id,
      name: name ?? this.name,
      area: area ?? this.area,
      city: city ?? this.city,
      sport: sport ?? this.sport,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      rating: rating,
      reviewsCount: reviewsCount,
      openHour: openHour ?? this.openHour,
      closeHour: closeHour ?? this.closeHour,
      ownerId: ownerId,
      imageUrl: imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      description: description,
      amenities: amenities,
      lat: lat,
      lng: lng,
      surfaceType: surfaceType,
      sizeLabel: sizeLabel,
      placeId: placeId,
      photoName: photoName,
      phone: phone,
      isOpen: isOpen ?? this.isOpen,
      mapsUrl: mapsUrl ?? this.mapsUrl,
      promoImageUrls: promoImageUrls ?? this.promoImageUrls,
      highlights: highlights ?? this.highlights,
      paymentDeposit: paymentDeposit ?? this.paymentDeposit,
      paymentCashOnArrival: paymentCashOnArrival ?? this.paymentCashOnArrival,
      zainCashEnabled: zainCashEnabled ?? this.zainCashEnabled,
      zainCashMerchantId: zainCashMerchantId ?? this.zainCashMerchantId,
      services: services ?? this.services,
    );
  }

  /// نوع الأرضية — إذا مو مخزّن ننطي افتراضي حسب الرياضة
  String get surfaceLabel {
    if (surfaceType.isNotEmpty) return surfaceType;
    return switch (sport) {
      Sport.football => 'عشب صناعي',
      Sport.basketball => 'باركيه',
      Sport.tennis => 'أرضية صلبة',
      Sport.padel => 'زجاج وعشب',
      Sport.volleyball => 'أرضية صلبة',
      Sport.swimming => 'مسبح',
      Sport.gym => 'صالة مغلقة',
      Sport.sportsCentre => 'متعدد',
      Sport.therapy => 'غرف علاج',
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
      Sport.volleyball => '٦ × ٦',
      Sport.swimming => 'مسارات',
      Sport.gym => 'صالة',
      Sport.sportsCentre => 'مجمع',
      Sport.therapy => 'جلسات',
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
