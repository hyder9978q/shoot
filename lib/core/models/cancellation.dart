import 'field.dart';

/// سجل إلغاء صادر من صاحب الملعب — ينخزن بمجموعة cancellations.
///
/// ليش مجموعة منفصلة ومو حقل بالحجز؟ لأن الحجز ينحذف حتى يتحرر الوقت
/// للاعبين الثانين (معرّف المستند fieldId_date_hour يمنع الحجز المزدوج).
/// السجل يبقى دليل دائم: يحسب "إلغاء غير مسؤول عنه" باللاعب،
/// و"نسبة الالتزام" بالملعب.
class Cancellation {
  const Cancellation({
    required this.id,
    required this.playerId,
    required this.playerPhone,
    required this.fieldId,
    required this.fieldName,
    required this.ownerId,
    required this.area,
    required this.city,
    required this.sport,
    required this.lat,
    required this.lng,
    required this.date,
    required this.hour,
    required this.deposit,
    required this.cancelledAtMs,
    this.reason = '',
    this.seen = false,
    this.compensated = false,
  });

  factory Cancellation.fromMap(String id, Map<String, dynamic> data) {
    return Cancellation(
      id: id,
      playerId: (data['playerId'] as String?) ?? '',
      playerPhone: (data['playerPhone'] as String?) ?? '',
      fieldId: (data['fieldId'] as String?) ?? '',
      fieldName: (data['fieldName'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      area: (data['area'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      sport: Sport.values.firstWhere(
        (s) => s.name == data['sport'],
        orElse: () => Sport.football,
      ),
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      date: (data['date'] as String?) ?? '',
      hour: (data['hour'] as num?)?.toInt() ?? 0,
      deposit: (data['deposit'] as num?)?.toInt() ?? 0,
      cancelledAtMs: (data['cancelledAtMs'] as num?)?.toInt() ?? 0,
      reason: (data['reason'] as String?) ?? '',
      seen: (data['seen'] as bool?) ?? false,
      compensated: (data['compensated'] as bool?) ?? false,
    );
  }

  /// نفس معرّف الحجز الملغي (fieldId_date_hour)
  final String id;

  /// اللاعب المتضرر
  final String playerId;
  final String playerPhone;

  final String fieldId;
  final String fieldName;

  /// صاحب الملعب اللي ألغى — منه تنحسب نسبة الالتزام
  final String ownerId;

  final String area;
  final String city;
  final Sport sport;

  /// موقع الملعب الملغي — منه نرتب البدائل بالأقرب
  final double lat;
  final double lng;

  final String date;
  final int hour;
  final int deposit;
  final int cancelledAtMs;

  /// سبب الإلغاء بكلام صاحب الملعب (منظّف ومحدود الطول)
  final String reason;

  /// اللاعب شاف الإشعار؟
  final bool seen;

  /// استخدم اللاعب أولوية "محجوز مضمون" مقابل هذا الإلغاء؟
  final bool compensated;

  bool get hasLocation => lat != 0 || lng != 0;

  String get location => '$area، $city';

  Map<String, dynamic> toMap() => {
        'playerId': playerId,
        'playerPhone': playerPhone,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'ownerId': ownerId,
        'area': area,
        'city': city,
        'sport': sport.name,
        'lat': lat,
        'lng': lng,
        'date': date,
        'hour': hour,
        'deposit': deposit,
        'cancelledAtMs': cancelledAtMs,
        'reason': reason,
        'seen': seen,
        'compensated': compensated,
      };

  Cancellation copyWith({bool? seen, bool? compensated}) => Cancellation(
        id: id,
        playerId: playerId,
        playerPhone: playerPhone,
        fieldId: fieldId,
        fieldName: fieldName,
        ownerId: ownerId,
        area: area,
        city: city,
        sport: sport,
        lat: lat,
        lng: lng,
        date: date,
        hour: hour,
        deposit: deposit,
        cancelledAtMs: cancelledAtMs,
        reason: reason,
        seen: seen ?? this.seen,
        compensated: compensated ?? this.compensated,
      );
}

/// نسبة التزام ملعب — كم حجز أكمله مقابل كم ألغاه
class FieldReliability {
  const FieldReliability({required this.kept, required this.cancelled});

  /// حجوزات ما انلغت من صاحب الملعب
  final int kept;

  /// حجوزات ألغاها صاحب الملعب
  final int cancelled;

  int get total => kept + cancelled;

  /// نسبة الالتزام ٠-١٠٠
  int get percent => total == 0 ? 100 : ((kept / total) * 100).round();

  /// ما نعرض النسبة إلا بعد عدد كافي من الحجوزات — تحت هذا الحد
  /// الرقم يضلل أكثر ما يفيد
  static const int minSample = 5;

  bool get hasEnoughData => total >= minSample;

  /// ملعب جاد؟ (نعرض الشارة الخضراء)
  bool get isReliable => percent >= 90;

  /// كثير إلغاءات — تحذير للاعب
  bool get isRisky => percent < 75;
}
