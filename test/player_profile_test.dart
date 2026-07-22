import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/core/models/field.dart';
import 'package:shoot/core/models/player_stats.dart';
import 'package:shoot/core/services/bookings_service.dart';
import 'package:shoot/core/services/fields_service.dart';
import 'package:shoot/core/services/leaderboard_service.dart';
import 'package:shoot/core/services/player_requests_service.dart';
import 'package:shoot/core/services/player_stats_service.dart';
import 'package:shoot/core/services/request_responses_service.dart';
import 'package:shoot/core/services/user_service.dart';
import 'package:shoot/core/utils/date_labels.dart';

/// ملف اللاعب، الشارات، ترتيب الحي، وانضمامات "ناقصنا لاعب" — كل رقم
/// لازم يكون محسوب من بيانات حقيقية بوضع الاختبار (نفس مبدأ التطبيق).
void main() {
  final bookings = BookingsService.instance;
  final requests = RequestResponsesService.instance;

  setUp(() {
    DateLabels.debugNow = DateTime(2026, 7, 15);
    bookings.debugReset();
    requests.debugReset();
    UserService.instance.resetForSignOut();
  });

  tearDown(() {
    DateLabels.debugNow = null;
    bookings.debugReset();
    requests.debugReset();
    UserService.instance.resetForSignOut();
  });

  Future<Field> ownedField() async {
    final all = await FieldsService.instance.loadAllFields();
    return all.firstWhere((f) => f.ownerId == 'mock-user');
  }

  group('شارات اللاعب — منطق العتبات', () {
    test('ما بيه شارات بدون بيانات', () {
      const stats = PlayerStats(
        matchesPlayed: 0,
        gapsFilled: 0,
        selfCancellations: 0,
        hasEverBooked: false,
      );
      expect(stats.earnedBadges, isEmpty);
      expect(stats.isCommitted, isFalse);
    });

    test('أول حجز تنعطى بمجرد إثبات حجز حقيقي واحد', () {
      const stats = PlayerStats(
        matchesPlayed: 0,
        gapsFilled: 0,
        selfCancellations: 0,
        hasEverBooked: true,
      );
      expect(stats.earnedBadges, contains(PlayerBadge.firstBooking));
      expect(stats.earnedBadges, isNot(contains(PlayerBadge.tenMatches)));
    });

    test('١٠ مباريات فأكثر تعطي شارة تخصها', () {
      const stats = PlayerStats(
        matchesPlayed: 10,
        gapsFilled: 0,
        selfCancellations: 0,
        hasEverBooked: true,
      );
      expect(stats.earnedBadges, contains(PlayerBadge.tenMatches));
    });

    test('٥ مرات إكمال نقص تعطي شارة منقذ', () {
      const stats = PlayerStats(
        matchesPlayed: 0,
        gapsFilled: 5,
        selfCancellations: 0,
        hasEverBooked: false,
      );
      expect(stats.earnedBadges, contains(PlayerBadge.rescuer));
    });

    test('ملتزم تحتاج عيّنة كافية وصفر إلغاء ذاتي', () {
      const notEnough = PlayerStats(
        matchesPlayed: 1,
        gapsFilled: 0,
        selfCancellations: 0,
        hasEverBooked: true,
      );
      expect(notEnough.isCommitted, isFalse);

      const committed = PlayerStats(
        matchesPlayed: 3,
        gapsFilled: 0,
        selfCancellations: 0,
        hasEverBooked: true,
      );
      expect(committed.isCommitted, isTrue);
      expect(committed.earnedBadges, contains(PlayerBadge.committed));

      const cancelledOnce = PlayerStats(
        matchesPlayed: 5,
        gapsFilled: 0,
        selfCancellations: 1,
        hasEverBooked: true,
      );
      expect(cancelledOnce.isCommitted, isFalse);
      expect(
        cancelledOnce.earnedBadges,
        isNot(contains(PlayerBadge.committed)),
      );
    });
  });

  group('إحصائيات BookingsService — محسوبة من الحجوزات الحقيقية بس', () {
    test('عدد المباريات المكتملة يحسب الماضي فقط، مو المستقبل', () async {
      final field = await ownedField();
      // حجز مضى — يحسب
      await bookings.createBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: DateLabels.dateFor(-2),
      );
      // حجز مستقبلي — ما يحسب لسا (المباراة ما صارت)
      await bookings.createBooking(
        field,
        TimeSlot(hour: field.openHour + 1, isBooked: false),
        date: DateLabels.dateFor(5),
      );

      expect(await bookings.matchesPlayedCount('mock-user'), 1);
      expect(await bookings.totalBookingsCount('mock-user'), 2);
    });

    test('الإلغاء الذاتي ينسجل ويحسب لشارة ملتزم', () async {
      final field = await ownedField();
      final booking = await bookings.createBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: DateLabels.dateFor(-1),
      );

      expect(await bookings.selfCancellationsCount('mock-user'), 0);
      await bookings.cancelBooking(booking);
      expect(await bookings.selfCancellationsCount('mock-user'), 1);

      // الحجز انحذف — ما يبين بالمباريات ولا الحجوزات الكلية
      expect(await bookings.matchesPlayedCount('mock-user'), 0);
      expect(await bookings.totalBookingsCount('mock-user'), 0);
    });

    test(
      'PlayerStatsService: حجز مو بذنبه (انلغى) يثبت "حجز ولو مرة"',
      () async {
        final field = await ownedField();
        final booking = await bookings.createBooking(
          field,
          TimeSlot(hour: field.openHour, isBooked: false),
          date: DateLabels.dateFor(-1),
        );
        await bookings.cancelBooking(booking);

        final stats = await PlayerStatsService.instance.statsFor('mock-user');
        expect(
          stats.hasEverBooked,
          isTrue,
          reason: 'انحجز فعلاً حتى لو الحجز انحذف بعدين',
        );
        expect(stats.matchesPlayed, 0);
        expect(stats.selfCancellations, 1);
      },
    );
  });

  group('انضمامات ناقصنا لاعب', () {
    test('الانضمام والانسحاب يغيّران العدد الحقيقي', () async {
      final all = await PlayerRequestsService.instance.todayRequests();
      final r1 = all.firstWhere((r) => r.userId != 'mock-user');

      expect(requests.hasResponded(r1.id), isFalse);
      await requests.respond(r1);
      expect(requests.hasResponded(r1.id), isTrue);
      expect(await requests.gapsFilledCount('mock-user'), 1);

      await requests.withdraw(r1);
      expect(requests.hasResponded(r1.id), isFalse);
      expect(await requests.gapsFilledCount('mock-user'), 0);
    });

    test('ما تنفع على إعلانك انت', () async {
      await PlayerRequestsService.instance.createRequest(
        sport: Sport.football,
        place: 'ملعبي الخاص',
        hour: 19,
        playersNeeded: 1,
      );
      final all = await PlayerRequestsService.instance.todayRequests();
      final mine = all.firstWhere((r) => r.userId == 'mock-user');

      await requests.respond(mine);
      expect(requests.hasResponded(mine.id), isFalse);
      expect(await requests.gapsFilledCount('mock-user'), 0);
    });
  });

  group('ترتيب الحي/المدينة', () {
    test('يحسب مباريات هذا الشهر بنفس المدينة بس', () async {
      final field = await ownedField(); // f1 — بغداد
      await bookings.createBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: DateLabels.dateFor(-1), // هذا الشهر
      );
      await UserService.instance.saveCity(field.city);

      final result = await LeaderboardService.instance.monthly(field.city);
      expect(result.myMatches, 1);
      expect(result.myRank, 1);
      expect(result.top, isNotEmpty);
      expect(result.top.first.userId, 'mock-user');
    });

    test('حجز شهر ثاني ما يحسب بترتيب هذا الشهر', () async {
      final field = await ownedField();
      // تاريخ الشهر الماضي — برّا نطاق "هذا الشهر"
      final lastMonth = DateTime(2026, 6, 10);
      final dateStr =
          '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}-10';
      await bookings.createBooking(
        field,
        TimeSlot(hour: field.openHour, isBooked: false),
        date: dateStr,
      );

      final result = await LeaderboardService.instance.monthly(field.city);
      expect(result.myMatches, 0);
      expect(result.myRank, 0);
    });

    test('مدينة بدون حجوزات هذا الشهر ترجع نتيجة فاضية', () async {
      final result = await LeaderboardService.instance.monthly('مدينة وهمية');
      expect(result.top, isEmpty);
      expect(result.myRank, 0);
    });
  });
}
