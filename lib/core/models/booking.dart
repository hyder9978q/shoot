import 'field.dart';

/// حجز ملعب — ينخزن بمجموعة bookings بـ Firestore
///
/// معرّف المستند: fieldId_date_hour — هذا يمنع حجز نفس الوقت مرتين:
/// أول واحد يكتب المستند يفوز، والثاني ينرفض من قواعد الحماية.
class Booking {
  const Booking({
    required this.id,
    required this.userId,
    required this.fieldId,
    required this.fieldName,
    required this.area,
    required this.city,
    required this.sport,
    required this.date,
    required this.hour,
    required this.deposit,
    this.userPhone = '',
    this.depositWaived = false,
    this.replacesCancellationId = '',
  });

  factory Booking.fromMap(String id, Map<String, dynamic> data) {
    return Booking(
      id: id,
      userId: (data['userId'] as String?) ?? '',
      fieldId: (data['fieldId'] as String?) ?? '',
      fieldName: (data['fieldName'] as String?) ?? '',
      area: (data['area'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      sport: Sport.values.firstWhere(
        (s) => s.name == data['sport'],
        orElse: () => Sport.football,
      ),
      date: (data['date'] as String?) ?? '',
      hour: (data['hour'] as num?)?.toInt() ?? 0,
      deposit: (data['deposit'] as num?)?.toInt() ?? 0,
      userPhone: (data['userPhone'] as String?) ?? '',
      depositWaived: (data['depositWaived'] as bool?) ?? false,
      replacesCancellationId:
          (data['replacesCancellationId'] as String?) ?? '',
    );
  }

  final String id;
  final String userId;
  final String fieldId;
  final String fieldName;
  final String area;
  final String city;
  final Sport sport;

  /// تاريخ الحجز بصيغة yyyy-MM-dd
  final String date;

  /// ساعة البداية (17 يعني من 5 لـ 6 مساءً)
  final int hour;

  /// العربون المدفوع بالدينار
  final int deposit;

  /// رقم اللاعب — حتى صاحب الملعب يگدر يوصله بالواتساب لو اضطر يلغي
  final String userPhone;

  /// حجز بديل بعد إلغاء مو ذنب اللاعب → معفي من العربون ("محجوز مضمون")
  final bool depositWaived;

  /// معرّف سجل الإلغاء اللي هذا الحجز بديل عنه — فارغ = حجز عادي
  final String replacesCancellationId;

  /// حجز مضمون؟ (بديل عن إلغاء مو ذنب اللاعب)
  bool get isGuaranteed => replacesCancellationId.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'fieldId': fieldId,
        'fieldName': fieldName,
        'area': area,
        'city': city,
        'sport': sport.name,
        'date': date,
        'hour': hour,
        'deposit': deposit,
        'userPhone': userPhone,
        'depositWaived': depositWaived,
        'replacesCancellationId': replacesCancellationId,
      };

  String get location => '$area، $city';

  /// نص الوقت مثل 17:00 - 18:00
  String get timeLabel => TimeSlot(hour: hour, isBooked: false).label;
}
