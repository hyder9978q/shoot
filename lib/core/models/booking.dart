import 'field.dart';

/// حجز ملعب — ينخزن بمجموعة bookings بـ Firestore
///
/// معرّف المستند: fieldId_date_hour — هذا يمنع حجز نفس الوقت مرتين:
/// أول واحد يكتب المستند يفوز، والثاني ينرفض من قواعد الحماية.
///
/// المستند الرئيسي مقروء لأي مستخدم مسجّل (منه تنعرف الأوقات المحجوزة)،
/// فما ينخزن بيه أي شي شخصي. بيانات التواصل (رقم اللاعب، واسم زبون
/// الحجز اليدوي وملاحظته) تنخزن بمستند فرعي خاص
/// bookings/{id}/private/contact ما يقراه غير صاحب الحجز وصاحب المنشأة —
/// شوف [Booking.contactMap] و BookingsService.hydrateContacts.
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
    this.isManual = false,
    this.customerName = '',
    this.note = '',
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
      depositWaived: (data['depositWaived'] as bool?) ?? false,
      replacesCancellationId: (data['replacesCancellationId'] as String?) ?? '',
      isManual: (data['isManual'] as bool?) ?? false,
      // حجوزات قديمة انكتبت قبل ما تنفصل بيانات التواصل بمستند خاص —
      // نقراها منها حتى تضل شغالة. الحجوزات الجديدة ما بيها هذي
      // الحقول أصلاً (قواعد Firestore ترفضها)، فتنقرأ فاضية وتنعبى من
      // المستند الفرعي عبر [withContact].
      userPhone: (data['userPhone'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? '',
      note: (data['note'] as String?) ?? '',
    );
  }

  /// نسخة من الحجز مع بيانات التواصل المقروءة من المستند الفرعي الخاص
  Booking withContact(Map<String, dynamic> contact) => Booking(
    id: id,
    userId: userId,
    fieldId: fieldId,
    fieldName: fieldName,
    area: area,
    city: city,
    sport: sport,
    date: date,
    hour: hour,
    deposit: deposit,
    userPhone: (contact['userPhone'] as String?) ?? '',
    depositWaived: depositWaived,
    replacesCancellationId: replacesCancellationId,
    isManual: isManual,
    customerName: (contact['customerName'] as String?) ?? '',
    note: (contact['note'] as String?) ?? '',
  );

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

  /// رقم اللاعب — حتى صاحب الملعب يگدر يوصله بالواتساب لو اضطر يلغي.
  /// ما ينخزن بالمستند الرئيسي أبداً: مصدره المستند الفرعي الخاص
  /// bookings/{id}/private/contact، فيبقى فارغ لين ما ينقرأ منه.
  final String userPhone;

  /// حجز بديل بعد إلغاء مو ذنب اللاعب → معفي من العربون ("محجوز مضمون")
  final bool depositWaived;

  /// معرّف سجل الإلغاء اللي هذا الحجز بديل عنه — فارغ = حجز عادي
  final String replacesCancellationId;

  /// حجز يدوي من صاحب الملعب (زبون حجز خارج التطبيق) — userId فارغ دائماً
  /// لهذا النوع، حتى ما يبين غلط بـ"حجوزاتي" أي لاعب حقيقي (وحتى صاحب
  /// الملعب نفسه لو هو أيضاً لاعب بحساب ثاني)
  final bool isManual;

  /// اسم الزبون — للحجز اليدوي بس. خاص مثل [userPhone]: مصدره المستند
  /// الفرعي bookings/{id}/private/contact مو المستند الرئيسي.
  final String customerName;

  /// ملاحظة صاحب الملعب على الحجز اليدوي (اختيارية) — خاصة مثلها
  final String note;

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
    'depositWaived': depositWaived,
    'replacesCancellationId': replacesCancellationId,
    'isManual': isManual,
  };

  /// بيانات التواصل الخاصة — تنكتب بالمستند الفرعي
  /// bookings/{id}/private/contact وحده، مو بالمستند الرئيسي.
  /// fieldId/date/hour منسوخة معها حتى تتحقق القواعد من هوية الحجز
  /// وملكيته بدون ما تحتاج تقرأ المستند الأب.
  Map<String, dynamic> get contactMap => {
    'userId': userId,
    'fieldId': fieldId,
    'date': date,
    'hour': hour,
    'userPhone': userPhone,
    'customerName': customerName,
    'note': note,
  };

  String get location => '$area، $city';

  /// نص الوقت مثل ٥:٠٠ مساءً - ٦:٠٠ مساءً
  String get timeLabel => TimeSlot(hour: hour, isBooked: false).label;
}
