/// شارات اللاعب — تُمنح تلقائياً على إنجازات حقيقية بس، محسوبة من
/// [PlayerStats]. ما بيها شارة تُكتب يدوياً — كلها مشتقة من بيانات فعلية
/// (نفس مبدأ مؤشر الموثوقية بالملاعب).
enum PlayerBadge {
  /// أول حجز إلك بالتطبيق
  firstBooking('أول حجز', '📋'),

  /// لعبت ١٠ مباريات فأكثر
  tenMatches('١٠ مباريات', '🏆'),

  /// كمّلت نقص فريق ٥ مرات فأكثر ("ناقصنا لاعب")
  rescuer('منقذ', '🦸'),

  /// عندك تاريخ حجوزات حقيقي وما ألغيت ولا وحدة بنفسك
  committed('ملتزم', '✅');

  const PlayerBadge(this.label, this.emoji);

  final String label;
  final String emoji;

  String get description => switch (this) {
    PlayerBadge.firstBooking => 'حجزت أول ملعب إلك بشوت',
    PlayerBadge.tenMatches => 'لعبت ١٠ مباريات فأكثر عبر التطبيق',
    PlayerBadge.rescuer => 'كملت نقص فريق ٥ مرات فأكثر',
    PlayerBadge.committed => 'عندك تاريخ حجوزات حقيقي وما ألغيت ولا حجز',
  };
}

/// إحصائيات لاعب — كل رقم بيها محسوب من بيانات Firestore حقيقية
/// (حجوزات، إعلانات "ناقصنا لاعب" حقيقية انضم إلها، إلغاءات فعلية).
/// ما بيها أي رقم يدوي أو تجريبي — القيم تُشتق دائماً، وين ما توفرت بيانات
/// كافية تنعرض القيمة الحقيقية (وحتى لو صفر) بدل رقم مختلق.
class PlayerStats {
  const PlayerStats({
    required this.matchesPlayed,
    required this.gapsFilled,
    required this.selfCancellations,
    required this.hasEverBooked,
  });

  /// عدد المباريات المكتملة (حجوزات بتاريخ مضى أو اليوم)
  final int matchesPlayed;

  /// عدد المرات اللي كمّل فيها نقص فريق ("ناقصنا لاعب")
  final int gapsFilled;

  /// عدد المرات اللي ألغى فيها اللاعب حجزه بنفسه
  final int selfCancellations;

  /// هل حجز ولو مرة وحدة بالتطبيق (حتى لو الحجز انلغى بعدين)؟
  final bool hasEverBooked;

  /// أقل عدد مباريات حتى نعرض شارة "ملتزم" — تاريخ قصير جداً ما يثبت التزام
  static const int committedMinSample = 3;

  /// أقل عدد مباريات لشارة "١٠ مباريات"
  static const int tenMatchesThreshold = 10;

  /// أقل عدد مرات إكمال نقص لشارة "منقذ"
  static const int rescuerThreshold = 5;

  bool get isCommitted =>
      matchesPlayed >= committedMinSample && selfCancellations == 0;

  /// الشارات اللي حصّلها اللاعب فعلاً — بالترتيب اللي تنعرض بيه
  Set<PlayerBadge> get earnedBadges => {
    if (hasEverBooked) PlayerBadge.firstBooking,
    if (matchesPlayed >= tenMatchesThreshold) PlayerBadge.tenMatches,
    if (gapsFilled >= rescuerThreshold) PlayerBadge.rescuer,
    if (isCommitted) PlayerBadge.committed,
  };
}

/// ملف عام لأي لاعب — يُقرأ من مجموعة players (نسخة آمنة للعرض العام،
/// بدون رقم الهاتف أو أي بيانات خاصة تبقى بمستند users/{uid} وحده).
class PublicPlayerProfile {
  const PublicPlayerProfile({
    required this.name,
    required this.city,
    required this.photoUrl,
    required this.joinedAtMs,
  });

  final String name;
  final String city;
  final String photoUrl;

  /// وقت إنشاء الحساب بالميلي ثانية — null إذا ما توفر (بيانات ناقصة)
  final int? joinedAtMs;
}
