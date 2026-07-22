import 'field.dart';
import '../utils/time_labels.dart';

/// إعلان "ناقصنا لاعب" — فريق يدوّر لاعبين يكملون الفريق
class PlayerRequest {
  const PlayerRequest({
    required this.id,
    required this.userId,
    required this.phone,
    required this.sport,
    required this.place,
    required this.date,
    required this.hour,
    required this.playersNeeded,
    this.note = '',
  });

  factory PlayerRequest.fromMap(String id, Map<String, dynamic> data) {
    return PlayerRequest(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      sport: Sport.values.firstWhere(
        (s) => s.name == data['sport'],
        orElse: () => Sport.football,
      ),
      place: (data['place'] as String?) ?? '',
      date: (data['date'] as String?) ?? '',
      hour: (data['hour'] as num?)?.toInt() ?? 0,
      playersNeeded: (data['playersNeeded'] as num?)?.toInt() ?? 1,
      note: (data['note'] as String?) ?? '',
    );
  }

  final String id;
  final String userId;

  /// رقم التواصل بصيغة دولية +964...
  final String phone;
  final Sport sport;

  /// المكان (مثال: ملعب النجوم — المنصور)
  final String place;

  /// تاريخ اللعبة yyyy-MM-dd
  final String date;

  /// ساعة اللعبة (17 يعني 5 مساءً)
  final int hour;

  /// چم لاعب ناقصهم (1–5)
  final int playersNeeded;

  /// ملاحظة اختيارية (مثال: المستوى وسط، اللعبة جدية)
  final String note;

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'phone': phone,
    'sport': sport.name,
    'place': place,
    'date': date,
    'hour': hour,
    'playersNeeded': playersNeeded,
    'note': note,
  };

  /// عنوان الإعلان: "ناقصهم لاعب واحد" / "ناقصهم 3 لاعبين"
  String get title =>
      playersNeeded == 1 ? 'ناقصهم لاعب واحد' : 'ناقصهم $playersNeeded لاعبين';

  /// وقت اللعبة مثل ٨:٠٠ مساءً
  String get timeLabel => TimeLabels.hour12(hour);
}
