import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_core/firebase_core.dart';

import '../models/leaderboard_entry.dart';
import 'bookings_service.dart';
import 'user_service.dart';

/// نتيجة ترتيب الحي/المدينة — أفضل ١٠ + ترتيب المستخدم الحالي حتى لو
/// مو ضمن العشرة الأوائل.
class LeaderboardResult {
  const LeaderboardResult({
    required this.top,
    required this.myRank,
    required this.myMatches,
  });

  final List<LeaderboardEntry> top;

  /// ترتيبي (من ١) — صفر يعني ما لعبت هذا الشهر بهاي المدينة
  final int myRank;
  final int myMatches;

  static const empty = LeaderboardResult(top: [], myRank: 0, myMatches: 0);
}

/// ترتيب نشاط اللاعبين ضمن مدينة واحدة هذا الشهر — محسوب من حجوزات
/// حقيقية فقط. Firestore ما يگدر يجمّع (GROUP BY) حسب اللاعب مباشرة،
/// فنجيب حجوزات المدينة هذا الشهر ونجمعها بالتطبيق (نفس أسلوب باقي
/// الخدمة بتجميع حجوزات اليوم للملاعب كافة).
class LeaderboardService {
  LeaderboardService._();

  static final LeaderboardService instance = LeaderboardService._();

  bool get _useMock => Firebase.apps.isEmpty;

  static const int topSize = 10;

  Future<LeaderboardResult> monthly(String city) async {
    if (city.isEmpty) return LeaderboardResult.empty;

    final myUid = UserService.instance.uid;
    final bookings = await BookingsService.instance.bookingsInCityThisMonth(
      city,
    );

    final counts = <String, int>{};
    for (final b in bookings) {
      if (b.userId.isEmpty) continue;
      counts[b.userId] = (counts[b.userId] ?? 0) + 1;
    }

    final sortedIds = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final topIds = sortedIds.take(topSize).toList();
    final names = await _namesFor(topIds);

    final top = [
      for (var i = 0; i < topIds.length; i++)
        LeaderboardEntry(
          userId: topIds[i],
          name: names[topIds[i]] ?? '',
          matchesThisMonth: counts[topIds[i]]!,
          rank: i + 1,
        ),
    ];

    final myIndex = sortedIds.indexOf(myUid);
    return LeaderboardResult(
      top: top,
      myRank: myIndex == -1 ? 0 : myIndex + 1,
      myMatches: myIndex == -1 ? 0 : counts[myUid]!,
    );
  }

  /// أسماء اللاعبين من مجموعة players (نسخة عامة آمنة — بدون رقم هاتف)
  Future<Map<String, String>> _namesFor(List<String> uids) async {
    if (uids.isEmpty) return {};
    if (_useMock) {
      return {for (final uid in uids) uid: _mockName(uid)};
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('players')
          .where(FieldPath.documentId, whereIn: uids)
          .get()
          .timeout(const Duration(seconds: 10));
      return {
        for (final doc in snapshot.docs)
          doc.id: (doc.data()['name'] as String?) ?? '',
      };
    } catch (_) {
      return {};
    }
  }

  String _mockName(String uid) =>
      uid == 'mock-user' ? UserService.instance.name : uid;
}
