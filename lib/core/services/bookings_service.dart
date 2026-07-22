import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import '../models/field.dart';
import '../utils/date_labels.dart';
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

  bool get _useMock => Firebase.apps.isEmpty;

  String get _uid => _useMock
      ? 'mock-user'
      : FirebaseAuth.instance.currentUser?.uid ?? '';

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
            isBooked: (isToday && h % 3 == 0) ||
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
                    (b) =>
                        b.fieldId == f.id && b.date == date && b.hour == h,
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
  Future<Booking> createBooking(
    Field field,
    TimeSlot slot, {
    String? date,
  }) {
    final pending = _pendingCreate;
    if (pending != null) return pending;
    final future = _createBooking(field, slot, date: date)
        .whenComplete(() => _pendingCreate = null);
    _pendingCreate = future;
    return future;
  }

  Future<Booking> _createBooking(
    Field field,
    TimeSlot slot, {
    String? date,
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
      deposit: FieldsService.depositAmount,
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
          .set({
        ...booking.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
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

    return [
      for (final doc in docs) Booking.fromMap(doc.id, doc.data()),
    ];
  }

  /// إلغاء حجز — يحذف المستند فيتحرر الوقت للآخرين
  Future<void> cancelBooking(Booking booking) async {
    // إلغاء نفس الحجز جاري؟ ما نكرر العملية
    if (!_cancelling.add(booking.id)) return;
    try {
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
    } finally {
      _cancelling.remove(booking.id);
    }
  }
}
