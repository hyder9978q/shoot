import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import '../models/field.dart';
import '../utils/date_labels.dart';
import 'app_mode.dart';
import 'fields_service.dart';

/// الوقت اللي اختاره المستخدم توه انحجز من شخص ثاني
class SlotTakenException implements Exception {
  const SlotTakenException();
}

/// خدمة الحجوزات — تكتب وتقرأ من Firestore،
/// وبوضع الاختبار (بدون Firebase) تشتغل على قائمة بالذاكرة.
class BookingsService {
  BookingsService._();

  static final BookingsService instance = BookingsService._();

  /// يزيد مع كل حجز/إلغاء — تبويب "حجوزاتي" يسمعه ويحدّث نفسه
  final ValueNotifier<int> revision = ValueNotifier(0);

  /// حجوزات وضع الاختبار (بدون Firebase)
  final List<Booking> _mockBookings = [];

  /// إلغاءات ذاتية بوضع الاختبار — عنصر لكل مرة اللاعب لغى حجزه بنفسه
  /// (نفس معرّف اللاعب يتكرر حسب عدد المرات؛ يكفي للعدّ بشارة "ملتزم")
  final List<String> _mockSelfCancellations = [];

  bool get _useMock => AppMode.isMock;

  String get _uid =>
      _useMock ? 'mock-user' : FirebaseAuth.instance.currentUser?.uid ?? '';

  /// رقم اللاعب — ينحفظ بالحجز حتى صاحب الملعب يوصله لو اضطر يلغي
  String get _phone => _useMock
      ? '+9647701234567'
      : FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

  /// تاريخ اليوم بصيغة yyyy-MM-dd
  static String todayDate() => DateLabels.dateFor(0);

  /// أوقات ملعب معيّن بيوم معيّن مع حالة الحجز الحقيقية
  Future<List<TimeSlot>> slotsFor(Field field, String date) async {
    if (_useMock) {
      // نمط تجريبي ثابت (اليوم فقط) + الحجوزات اللي انحجزت بنفس الجلسة
      final isToday = date == todayDate();
      return [
        for (var h = field.openHour; h < field.closeHour; h++)
          TimeSlot(
            hour: h,
            isBooked:
                (isToday && h % 3 == 0) ||
                _mockBookings.any(
                  (b) => b.fieldId == field.id && b.date == date && b.hour == h,
                ),
          ),
      ];
    }

    Set<int> booked;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('fieldId', isEqualTo: field.id)
          .where('date', isEqualTo: date)
          .get()
          .timeout(const Duration(seconds: 10));
      booked = {
        for (final doc in snapshot.docs)
          (doc.data()['hour'] as num?)?.toInt() ?? -1,
      };
    } catch (_) {
      booked = {};
    }

    return [
      for (var h = field.openHour; h < field.closeHour; h++)
        TimeSlot(hour: h, isBooked: booked.contains(h)),
    ];
  }

  /// الساعات المحجوزة اليوم لكل الملاعب دفعة وحدة (استعلام واحد)
  /// — يستخدمها قسم "العب اليوم" بالرئيسية
  Future<Map<String, Set<int>>> todayBookedHours(List<Field> fields) async {
    final date = todayDate();

    if (_useMock) {
      return {
        for (final f in fields)
          f.id: {
            for (var h = f.openHour; h < f.closeHour; h++)
              if (h % 3 == 0 ||
                  _mockBookings.any(
                    (b) => b.fieldId == f.id && b.date == date && b.hour == h,
                  ))
                h,
          },
      };
    }

    final map = <String, Set<int>>{};
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('date', isEqualTo: date)
          .get()
          .timeout(const Duration(seconds: 10));
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fieldId = (data['fieldId'] as String?) ?? '';
        final hour = (data['hour'] as num?)?.toInt() ?? -1;
        (map[fieldId] ??= {}).add(hour);
      }
    } catch (_) {
      // بدون نت: نرجع خريطة فارغة — القسم يعرض كل الأوقات كفاضية
    }
    return map;
  }

  /// عملية إنشاء جارية — أي نداء ثاني بنفس الوقت يرجع نفس النتيجة
  /// بدل ما يكتب مرتين على Firestore
  Future<Booking>? _pendingCreate;

  /// إلغاءات جارية (بمعرّف الحجز) — منع الحذف المزدوج
  final Set<String> _cancelling = {};

  /// إنشاء حجز بيوم معيّن — يرمي [SlotTakenException] إذا الوقت انحجز قبل ثواني
  ///
  /// [replacesCancellationId] يخلي الحجز "محجوز مضمون" (بديل عن إلغاء
  /// مو ذنب اللاعب)، و[depositWaived] يعفيه من العربون.
  Future<Booking> createBooking(
    Field field,
    TimeSlot slot, {
    String? date,
    String replacesCancellationId = '',
    bool depositWaived = false,
  }) {
    final pending = _pendingCreate;
    if (pending != null) return pending;
    final future = _createBooking(
      field,
      slot,
      date: date,
      replacesCancellationId: replacesCancellationId,
      depositWaived: depositWaived,
    ).whenComplete(() => _pendingCreate = null);
    _pendingCreate = future;
    return future;
  }

  Future<Booking> _createBooking(
    Field field,
    TimeSlot slot, {
    String? date,
    String replacesCancellationId = '',
    bool depositWaived = false,
  }) async {
    date ??= todayDate();
    final booking = Booking(
      id: '${field.id}_${date}_${slot.hour}',
      userId: _uid,
      fieldId: field.id,
      fieldName: field.name,
      area: field.area,
      city: field.city,
      sport: field.sport,
      date: date,
      hour: slot.hour,
      deposit: depositWaived ? 0 : FieldsService.depositAmount,
      userPhone: _phone,
      depositWaived: depositWaived,
      replacesCancellationId: replacesCancellationId,
    );

    if (_useMock) {
      final taken = _mockBookings.any(
        (b) => b.id == booking.id && b.userId != _uid,
      );
      if (taken) throw const SlotTakenException();
      _mockBookings.removeWhere((b) => b.id == booking.id);
      _mockBookings.add(booking);
      revision.value++;
      return booking;
    }

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .set({...booking.toMap(), 'createdAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 15));
    } on FirebaseException catch (e) {
      // قواعد الحماية ترفض الكتابة فوق حجز شخص ثاني
      if (e.code == 'permission-denied' || e.code == 'already-exists') {
        throw const SlotTakenException();
      }
      rethrow;
    }
    revision.value++;
    return booking;
  }

  /// عدد الحجوزات بالدفعة الوحدة
  static const int pageSize = 20;

  /// مؤشر آخر حجز وصلنا له — منه تبدي الدفعة الجاية
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  /// باقي حجوزات ما تحمّلت؟
  bool _hasMore = true;

  /// هل بعد بيه حجوزات تنتظر التحميل؟
  bool get hasMore => _hasMore;

  /// حجوزاتي — أول دفعة، الأحدث أولاً.
  /// كل نداء يبدي من الصفر (السحب-للتحديث وأي حجز/إلغاء).
  Future<List<Booking>> myBookings() async {
    _cursor = null;
    _hasMore = true;
    return _fetchBookingsPage();
  }

  /// الدفعة الجاية — يناديها التمرير لأسفل بتبويب حجوزاتي
  Future<List<Booking>> moreBookings() async {
    if (!_hasMore) return const [];
    return _fetchBookingsPage();
  }

  Future<List<Booking>> _fetchBookingsPage() async {
    if (_useMock) {
      _hasMore = false;
      return _mockBookings.reversed.toList();
    }

    // الترتيب بالسيرفر ضروري حتى يشتغل مؤشر الدفعات
    var query = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: _uid)
        .orderBy('date', descending: true)
        .orderBy('hour', descending: true)
        .limit(pageSize);
    final cursor = _cursor;
    if (cursor != null) query = query.startAfterDocument(cursor);

    final snapshot = await query.get().timeout(const Duration(seconds: 10));
    final docs = snapshot.docs;
    if (docs.isNotEmpty) _cursor = docs.last;
    // دفعة ناقصة = وصلنا للنهاية
    _hasMore = docs.length == pageSize;

    return [for (final doc in docs) Booking.fromMap(doc.id, doc.data())];
  }

  /// الملاعب المحجوزة بتاريخ وساعة معيّنة — يستخدمها بحث البدائل
  Future<Set<String>> takenFieldIdsAt(String date, int hour) async {
    if (_useMock) {
      return {
        for (final b in _mockBookings)
          if (b.date == date && b.hour == hour) b.fieldId,
        // النمط التجريبي: كل ساعة تقبل القسمة على ٣ محجوزة اليوم
        if (date == todayDate() && hour % 3 == 0) ...{'f1', 'f2'},
      };
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('date', isEqualTo: date)
          .where('hour', isEqualTo: hour)
          .get()
          .timeout(const Duration(seconds: 10));
      return {
        for (final doc in snapshot.docs)
          (doc.data()['fieldId'] as String?) ?? '',
      };
    } catch (_) {
      // بدون نت: ما نخفي بدائل — نعرضها وتنكشف عند الحجز
      return const {};
    }
  }

  /// حذف الحجز بعد ما ألغاه صاحب الملعب — يتحرر الوقت للاعبين الثانين.
  ///
  /// منفصل عن [cancelBooking] لأن الإلغاء هنا مو من اللاعب:
  /// السجل الدائم ينكتب بـ CancellationsService قبل الحذف.
  Future<void> removeForOwnerCancel(Booking booking) async {
    if (_useMock) {
      _mockBookings.removeWhere((b) => b.id == booking.id);
      revision.value++;
      return;
    }

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(booking.id)
        .delete()
        .timeout(const Duration(seconds: 15));
    revision.value++;
  }

  /// حجوزات ملعب معيّن بيوم معيّن — لوحة صاحب الملعب تستخدمها
  /// حتى يعرف منو اللاعب بكل وقت محجوز
  Future<List<Booking>> fieldBookings(String fieldId, String date) async {
    if (_useMock) {
      return [
        for (final b in _mockBookings)
          if (b.fieldId == fieldId && b.date == date) b,
      ];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('fieldId', isEqualTo: fieldId)
          .where('date', isEqualTo: date)
          .get()
          .timeout(const Duration(seconds: 10));
      return [
        for (final doc in snapshot.docs) Booking.fromMap(doc.id, doc.data()),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// إلغاء حجز — يحذف المستند فيتحرر الوقت للآخرين.
  ///
  /// قبل الحذف نسجّل دليل دائم بمجموعة playerCancellations — منه تنحسب
  /// شارة "ملتزم" لاحقاً (ما ألغى ولا حجز بنفسه). التسجيل بأفضل جهد:
  /// فشله ما يمنع تحرير الوقت، لأن هذا هو المطلب الأساسي للمستخدم.
  Future<void> cancelBooking(Booking booking) async {
    // إلغاء نفس الحجز جاري؟ ما نكرر العملية
    if (!_cancelling.add(booking.id)) return;
    try {
      if (_useMock) {
        _mockBookings.removeWhere((b) => b.id == booking.id);
        _mockSelfCancellations.add(booking.userId);
        revision.value++;
        return;
      }

      try {
        await FirebaseFirestore.instance
            .collection('playerCancellations')
            .doc(booking.id)
            .set({
              'userId': booking.userId,
              'fieldId': booking.fieldId,
              'date': booking.date,
              'hour': booking.hour,
              'cancelledAtMs': DateTime.now().millisecondsSinceEpoch,
            })
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // فشل السجل ما يوقف الإلغاء — الشارة بس تفوتها دقّة إضافية
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(booking.id)
          .delete()
          .timeout(const Duration(seconds: 15));
      revision.value++;
    } finally {
      _cancelling.remove(booking.id);
    }
  }

  // ---------- إحصائيات اللاعب (لملفه الشخصي وترتيب الحي) ----------
  //
  // كل رقم هنا محسوب من مستندات حقيقية بـ Firestore عبر عدّ مجمّع
  // (count) — أرخص من جلب المستندات ومستحيل تزويره من التطبيق،
  // لأن العميل ما يگدر يكتب هذا الرقم مباشرة بأي مكان.

  /// عدد المباريات المكتملة: حجوزات بتاريخ اليوم أو قبله
  Future<int> matchesPlayedCount(String uid) async {
    final today = todayDate();
    if (_useMock) {
      return _mockBookings
          .where((b) => b.userId == uid && b.date.compareTo(today) <= 0)
          .length;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .where('date', isLessThanOrEqualTo: today)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// كل حجوزات اللاعب الحالية (ماضية ومستقبلية) — لإثبات إنه حجز ولو مرة
  Future<int> totalBookingsCount(String uid) async {
    if (_useMock) {
      return _mockBookings.where((b) => b.userId == uid).length;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// عدد مرات إلغاء اللاعب حجزه بنفسه (لشارة "ملتزم")
  Future<int> selfCancellationsCount(String uid) async {
    if (_useMock) {
      return _mockSelfCancellations.where((id) => id == uid).length;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('playerCancellations')
          .where('userId', isEqualTo: uid)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// حجوزات هذا الشهر بنفس المدينة — خام (بدون تجميع) لترتيب الحي.
  /// نجلب المستندات لأن Firestore ما يگدر يجمّع (COUNT GROUP BY) حسب
  /// اللاعب مباشرة؛ الحد الأقصى يحمي من استعلام ضخم بمدينة نشيطة جداً.
  static const int leaderboardQueryLimit = 1000;

  Future<List<Booking>> bookingsInCityThisMonth(String city) async {
    final monthStart = DateLabels.monthStart();
    final today = todayDate();

    if (_useMock) {
      return _mockBookings
          .where(
            (b) =>
                b.city == city &&
                b.date.compareTo(monthStart) >= 0 &&
                b.date.compareTo(today) <= 0,
          )
          .toList();
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('city', isEqualTo: city)
          .where('date', isGreaterThanOrEqualTo: monthStart)
          .where('date', isLessThanOrEqualTo: today)
          .limit(leaderboardQueryLimit)
          .get()
          .timeout(const Duration(seconds: 15));
      return [
        for (final doc in snapshot.docs) Booking.fromMap(doc.id, doc.data()),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// تصفير وضع الاختبار — للاختبارات فقط
  @visibleForTesting
  void debugReset() {
    _mockBookings.clear();
    _mockSelfCancellations.clear();
    _cursor = null;
    _hasMore = true;
    revision.value++;
  }
}
