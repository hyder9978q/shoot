import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import '../models/cancellation.dart';
import '../models/field.dart';
import '../utils/geo.dart';
import '../utils/input_sanitizer.dart';
import 'bookings_service.dart';
import 'fields_service.dart';

/// ملعب بديل مقترح بعد إلغاء — ملعب + بُعده عن الملعب الملغي
class Alternative {
  const Alternative({required this.field, required this.distanceKm});

  final Field field;

  /// المسافة عن الملعب الملغي — -1 يعني ما نعرف (ما بيه إحداثيات)
  final double distanceKm;

  bool get hasDistance => distanceKm >= 0;
}

/// خدمة الإلغاءات — قلب فكرة "حلّال المشاكل".
///
/// لما صاحب الملعب يلغي حجز مؤكد:
/// ١. ينكتب سجل إلغاء دائم (دليل للاعب وللنسبة).
/// ٢. ينحذف الحجز حتى يتحرر الوقت لغيره.
/// ٣. اللاعب يشوف إشعار داخل التطبيق + رسالة واتساب من صاحب الملعب.
/// ٤. التطبيق يعرض بدائل بنفس اليوم والساعة والمدينة والرياضة.
class CancellationsService {
  CancellationsService._();

  static final CancellationsService instance = CancellationsService._();

  /// يزيد مع كل إلغاء/تحديث — الشاشات تسمعه وتحدّث نفسها
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get _useMock => Firebase.apps.isEmpty;

  String get _uid =>
      _useMock ? 'mock-user' : FirebaseAuth.instance.currentUser?.uid ?? '';

  /// سجلات وضع التجربة
  final List<Cancellation> _mock = [];

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('cancellations');

  /// الحد الأقصى لسبب الإلغاء
  static const int reasonMaxLength = 120;

  // ---------- إلغاء من صاحب الملعب ----------

  /// يلغي حجز مؤكد. صاحب الملعب فقط — وقواعد الحماية تفحصها بالسيرفر بعد.
  ///
  /// يرجّع سجل الإلغاء حتى الشاشة تفتح البدائل وترسل الواتساب.
  Future<Cancellation> cancelByOwner(
    Field field,
    Booking booking, {
    String reason = '',
  }) async {
    _assertOwner(field);
    if (booking.fieldId != field.id) {
      throw ArgumentError('الحجز مو تابع لهذا الملعب');
    }

    final record = Cancellation(
      id: booking.id,
      playerId: booking.userId,
      playerPhone: booking.userPhone,
      fieldId: field.id,
      fieldName: field.name,
      ownerId: field.ownerId,
      area: field.area,
      city: field.city,
      sport: field.sport,
      lat: field.lat,
      lng: field.lng,
      date: booking.date,
      hour: booking.hour,
      deposit: booking.deposit,
      cancelledAtMs: DateTime.now().millisecondsSinceEpoch,
      reason: InputSanitizer.clean(reason, maxLength: reasonMaxLength),
    );

    if (_useMock) {
      _mock.removeWhere((c) => c.id == record.id);
      _mock.add(record);
      await BookingsService.instance.removeForOwnerCancel(booking);
      revision.value++;
      return record;
    }

    // السجل أولاً: لو انحذف الحجز وفشل السجل يضيع حق اللاعب
    await _col
        .doc(record.id)
        .set(record.toMap())
        .timeout(const Duration(seconds: 15));
    await BookingsService.instance.removeForOwnerCancel(booking);
    revision.value++;
    return record;
  }

  /// فحص الملكية بالتطبيق — قواعد Firestore تفحصها بالسيرفر بعد
  void _assertOwner(Field field) {
    final uid = _uid;
    if (uid.isEmpty || field.ownerId != uid) {
      throw StateError('غير مخوّل: هذا الملعب مو تابع لحسابك');
    }
  }

  // ---------- سجل اللاعب ----------

  /// إلغاءات اللاعب الحالي — الأحدث أولاً
  Future<List<Cancellation>> myCancellations() async {
    final uid = _uid;
    if (uid.isEmpty) return const [];

    if (_useMock) {
      return [
        for (final c in _mock)
          if (c.playerId == uid) c,
      ]..sort((a, b) => b.cancelledAtMs.compareTo(a.cancelledAtMs));
    }

    try {
      final snapshot = await _col
          .where('playerId', isEqualTo: uid)
          .orderBy('cancelledAtMs', descending: true)
          .limit(50)
          .get()
          .timeout(const Duration(seconds: 10));
      return [
        for (final doc in snapshot.docs)
          Cancellation.fromMap(doc.id, doc.data()),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// إلغاءات ما شافها اللاعب بعد — منها يطلع الإشعار داخل التطبيق
  Future<List<Cancellation>> unseen() async {
    final all = await myCancellations();
    return [
      for (final c in all)
        if (!c.seen) c,
    ];
  }

  /// رصيد "محجوز مضمون" — كل إلغاء مو ذنب اللاعب يعطيه حجز بديل مضمون
  Future<int> guaranteedCredits() async {
    final all = await myCancellations();
    return all.where((c) => !c.compensated).length;
  }

  Future<void> markSeen(Cancellation cancellation) =>
      _patch(cancellation, {'seen': true});

  /// يستهلك الأولوية بعد ما يحجز اللاعب البديل
  Future<void> markCompensated(Cancellation cancellation) =>
      _patch(cancellation, {'compensated': true});

  Future<void> _patch(
    Cancellation cancellation,
    Map<String, Object?> data,
  ) async {
    if (cancellation.playerId != _uid) return;

    if (_useMock) {
      final i = _mock.indexWhere((c) => c.id == cancellation.id);
      if (i != -1) {
        _mock[i] = _mock[i].copyWith(
          seen: data['seen'] as bool?,
          compensated: data['compensated'] as bool?,
        );
      }
      revision.value++;
      return;
    }

    try {
      await _col
          .doc(cancellation.id)
          .update(data)
          .timeout(const Duration(seconds: 15));
      revision.value++;
    } catch (_) {
      // فشل التحديث ما يكسر التجربة — الإشعار يبين مرة ثانية
    }
  }

  // ---------- نسبة الالتزام ----------

  /// قيمة ثابتة للاختبارات — تعرض الشارة بأرقام معروفة
  @visibleForTesting
  static FieldReliability? debugReliability;

  /// نسبة التزام ملعب: حجوزات أكملها مقابل حجوزات ألغاها.
  ///
  /// نستخدم عدّ مجمّع (count) — أرخص بكثير من جلب المستندات.
  Future<FieldReliability> reliabilityFor(String fieldId) async {
    final injected = debugReliability;
    if (injected != null) return injected;

    // وضع التجربة ما عنده تاريخ حجوزات حقيقي — وما نخترع نسبة ثقة.
    // بدون بيانات = ما تبين الشارة أصلاً.
    if (_useMock) return const FieldReliability(kept: 0, cancelled: 0);

    try {
      final bookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('fieldId', isEqualTo: fieldId)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      final cancels = await _col
          .where('fieldId', isEqualTo: fieldId)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return FieldReliability(
        kept: bookings.count ?? 0,
        cancelled: cancels.count ?? 0,
      );
    } catch (_) {
      // بدون نت: ما نعرض نسبة مضللة
      return const FieldReliability(kept: 0, cancelled: 0);
    }
  }

  // ---------- إحصائيات اللاعب ----------

  /// عدد المرات اللي صاحب ملعب ألغى حجز هذا اللاعب — دليل إنه حجز فعلاً
  /// ولو ما بقى الحجز موجود (يستخدمها ملفه الشخصي لإثبات "أول حجز"
  /// حتى لو الحجز انلغى من الملعب مو منه).
  Future<int> cancelledAgainstCount(String uid) async {
    if (_useMock) {
      return _mock.where((c) => c.playerId == uid).length;
    }
    try {
      final snap = await _col
          .where('playerId', isEqualTo: uid)
          .count()
          .get()
          .timeout(const Duration(seconds: 10));
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ---------- البدائل ----------

  /// ملاعب بديلة بنفس اليوم والساعة والمدينة والرياضة — الأقرب أولاً.
  ///
  /// نستثني الملعب الملغي نفسه وأي ملعب محجوز بنفس الوقت أو مسكّر.
  Future<List<Alternative>> findAlternatives(Cancellation cancellation) async {
    final all = await FieldsService.instance.loadAllFields();
    final taken = await BookingsService.instance.takenFieldIdsAt(
      cancellation.date,
      cancellation.hour,
    );

    final matches = <Alternative>[];
    for (final field in all) {
      if (field.id == cancellation.fieldId) continue;
      if (field.city != cancellation.city) continue;
      if (field.sport != cancellation.sport) continue;
      if (!field.isOpen) continue;
      // الملعب دوامه يغطي الساعة؟
      if (cancellation.hour < field.openHour ||
          cancellation.hour >= field.closeHour) {
        continue;
      }
      if (taken.contains(field.id)) continue;

      final distance = field.hasLocation && cancellation.hasLocation
          ? Geo.distanceKm(
              cancellation.lat,
              cancellation.lng,
              field.lat,
              field.lng,
            )
          : -1.0;
      matches.add(Alternative(field: field, distanceKm: distance));
    }

    // الأقرب أولاً، واللي ما نعرف بُعده بالآخر ومرتب بالتقييم
    matches.sort((a, b) {
      if (a.hasDistance && b.hasDistance) {
        return a.distanceKm.compareTo(b.distanceKm);
      }
      if (a.hasDistance != b.hasDistance) return a.hasDistance ? -1 : 1;
      return b.field.rating.compareTo(a.field.rating);
    });
    return matches;
  }

  /// تصفير — للاختبارات
  @visibleForTesting
  void debugReset() {
    _mock.clear();
    revision.value++;
  }

  /// إضافة سجل جاهز — للاختبارات فقط
  @visibleForTesting
  void debugSeed(Cancellation cancellation) {
    _mock.add(cancellation);
    revision.value++;
  }
}
