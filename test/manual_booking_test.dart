import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/services/bookings_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/utils/date_labels.dart';

/// الحجز اليدوي لصاحب الملعب — نفس معرّف fieldId_date_hour ونفس منع
/// الحجز المزدوج للحجز العادي بالضبط، بالاتجاهين.
void main() {
  final fields = FieldsService.instance;
  final bookings = BookingsService.instance;

  setUp(() {
    DateLabels.debugNow = DateTime(2026, 7, 15);
    bookings.debugReset();
  });

  tearDown(() {
    DateLabels.debugNow = null;
    bookings.debugReset();
  });

  Future<Field> ownedField() async {
    final all = await fields.loadAllFields();
    return all.firstWhere((f) => f.ownerId == 'mock-user');
  }

  Future<Field> notOwnedField() async {
    final all = await fields.loadAllFields();
    return all.firstWhere((f) => f.ownerId != 'mock-user');
  }

  group('إنشاء حجز يدوي', () {
    testWidgets('ينسجّل بنفس معرّف fieldId_date_hour وبيانات الزبون',
        (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final booking = await bookings.createManualBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: date,
        customerName: 'أبو أحمد',
        customerPhone: '07701112233',
        note: 'يدفع كاش',
      );

      expect(booking.id, '${field.id}_${date}_${field.openHour}');
      expect(booking.isManual, isTrue);
      expect(booking.userId, isEmpty);
      expect(booking.customerName, 'أبو أحمد');
      expect(booking.userPhone, '07701112233');
      expect(booking.note, 'يدفع كاش');
      expect(booking.deposit, 0);

      // الوقت صار محجوز فعلاً بنفس نظام الحجز العادي
      final taken = await bookings.takenFieldIdsAt(date, field.openHour);
      expect(taken, contains(field.id));
    });

    testWidgets('ينظّف اسم الزبون من الرموز الخطيرة', (_) async {
      final field = await ownedField();
      final booking = await bookings.createManualBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: DateLabels.dateFor(1),
        customerName: '<script>alert(1)</script> أحمد',
      );
      expect(booking.customerName, isNot(contains('<')));
      expect(booking.customerName, contains('أحمد'));
    });

    testWidgets('اسم الزبون مطلوب', (_) async {
      final field = await ownedField();
      expect(
        () => bookings.createManualBooking(
          field,
          TimeSlot(hour: field.openHour, isBooked: false),
          date: DateLabels.dateFor(1),
          customerName: '   ',
        ),
        throwsArgumentError,
      );
    });

    testWidgets('ما يسمح لغير مالك الملعب', (_) async {
      final field = await notOwnedField();
      expect(
        () => bookings.createManualBooking(
          field,
          TimeSlot(hour: field.openHour, isBooked: false),
          date: DateLabels.dateFor(1),
          customerName: 'زبون',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('منع الحجز المزدوج بالاتجاهين', () {
    testWidgets('حجز يدوي يمنع لاعب من حجز نفس الوقت', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final slot = TimeSlot(hour: field.openHour, isBooked: false);

      await bookings.createManualBooking(
        field,
        slot,
        date: date,
        customerName: 'زبون تلفون',
      );

      expect(
        () => bookings.createBooking(field, slot, date: date),
        throwsA(isA<SlotTakenException>()),
      );
    });

    testWidgets('حجز لاعب حقيقي يمنع حجز يدوي فوقه', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final slot = TimeSlot(hour: field.openHour, isBooked: false);

      await bookings.createBooking(field, slot, date: date);

      expect(
        () => bookings.createManualBooking(
          field,
          slot,
          date: date,
          customerName: 'زبون ثاني',
        ),
        throwsA(isA<SlotTakenException>()),
      );
    });
  });

  group('إلغاء حجز يدوي', () {
    testWidgets('يحذف الحجز ويحرر الوقت', (_) async {
      final field = await ownedField();
      final date = DateLabels.dateFor(1);
      final slot = TimeSlot(hour: field.openHour, isBooked: false);
      final booking = await bookings.createManualBooking(
        field,
        slot,
        date: date,
        customerName: 'زبون',
      );

      var taken = await bookings.takenFieldIdsAt(date, field.openHour);
      expect(taken, contains(field.id));

      await bookings.cancelManualBooking(field, booking);

      taken = await bookings.takenFieldIdsAt(date, field.openHour);
      expect(taken, isNot(contains(field.id)));

      // ما يحسب إلغاء ذاتي (userId فارغ أصلاً، ما يخص أي لاعب حقيقي)
      expect(await bookings.selfCancellationsCount(''), 0);
    });

    testWidgets('ما يسمح لغير مالك الملعب يلغي', (_) async {
      final owned = await ownedField();
      final notOwned = await notOwnedField();
      final date = DateLabels.dateFor(1);
      final booking = await bookings.createManualBooking(
        owned,
        TimeSlot(hour: owned.openHour, isBooked: false),
        date: date,
        customerName: 'زبون',
      );

      expect(
        () => bookings.cancelManualBooking(notOwned, booking),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('الحجز اليدوي ما يخص أي حساب لاعب حقيقي', () {
    testWidgets('userId فارغ فما يبين بحجوزات أي لاعب', (_) async {
      final field = await ownedField();
      await bookings.createManualBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: DateLabels.dateFor(1),
        customerName: 'زبون',
      );

      expect(await bookings.matchesPlayedCount('mock-user'), 0);
      expect(await bookings.totalBookingsCount('mock-user'), 0);
    });
  });
}
