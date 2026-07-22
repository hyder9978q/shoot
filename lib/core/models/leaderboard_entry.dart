/// صف بترتيب الحي/المدينة — لاعب وعدد مبارياته هذا الشهر بنفس المدينة.
/// العدد محسوب من حجوزات حقيقية فقط (مجموعة bookings)، وين ما نعرف اسم
/// اللاعب (نادر) يبين اسم افتراضي بدل ما نخترع وحد.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.matchesThisMonth,
    required this.rank,
  });

  final String userId;
  final String name;
  final int matchesThisMonth;

  /// الترتيب بدءاً من ١
  final int rank;
}
