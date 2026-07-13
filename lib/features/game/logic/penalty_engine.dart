import 'dart:math';

/// مناطق المرمى الست: 3 أعمدة × صفين
enum GoalZone {
  topLeft(0, 0),
  topCenter(1, 0),
  topRight(2, 0),
  bottomLeft(0, 1),
  bottomCenter(1, 1),
  bottomRight(2, 1);

  const GoalZone(this.column, this.row);

  /// العمود: 0 يسار، 1 وسط، 2 يمين (من منظور المسدد)
  final int column;

  /// الصف: 0 عالي، 1 واطي
  final int row;

  bool get isTop => row == 0;
  bool get isCorner => column != 1;
}

/// نتيجة ضربة وحدة
class ShotOutcome {
  const ShotOutcome({
    required this.target,
    required this.keeperZone,
    required this.isGoal,
    required this.isMiss,
    required this.points,
  });

  /// وين سدد اللاعب
  final GoalZone target;

  /// وين نط الحارس
  final GoalZone keeperZone;

  /// گول؟
  final bool isGoal;

  /// طلعت برا الحديدة؟ (بس بالزوايا العالية)
  final bool isMiss;

  /// النقاط المكتسبة من هاي الضربة
  final int points;

  bool get isSaved => !isGoal && !isMiss;
}

/// نتيجة جولة كاملة (5 ضربات)
class GameResult {
  const GameResult({
    required this.score,
    required this.goals,
    required this.bestStreak,
  });

  final int score;
  final int goals;
  final int bestStreak;
}

/// محرك اللعبة — منطق خالص بدون واجهة، حتى نكدر نختبره بسهولة.
///
/// قوانين اللعبة:
/// - الحارس ينط لمنطقة عشوائية.
/// - إذا نط لنفس العمود: يصد بنسبة 85% للضربات الواطية و55% للعالية
///   (الضربات العالية أصعب عليه، بس...)
/// - الضربات بالزوايا العالية ممكن تطلع برا الحديدة بنسبة 10% (مخاطرة!)
/// - الگول: 100 نقطة + 50 إذا بزاوية عالية + 25 × سلسلة الأهداف المتتالية.
class PenaltyEngine {
  PenaltyEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// عدد الضربات بالجولة الوحدة
  static const int shotsPerGame = 5;

  /// نسبة الصد إذا الحارس بنفس العمود
  static const double lowSaveChance = 0.85;
  static const double highSaveChance = 0.55;

  /// نسبة الطلوع برا للزوايا العالية
  static const double topCornerMissChance = 0.10;

  ShotOutcome shoot(GoalZone target, {int currentStreak = 0}) {
    // مخاطرة الزوايا العالية: ممكن تطلع برا
    final isMiss = target.isTop &&
        target.isCorner &&
        _random.nextDouble() < topCornerMissChance;

    // الحارس يختار منطقة
    final keeperColumn = _random.nextInt(3);
    final keeperRow = _random.nextInt(2);
    final keeperZone = GoalZone.values.firstWhere(
      (z) => z.column == keeperColumn && z.row == keeperRow,
    );

    // الصد: لازم يكون بنفس العمود
    var saved = false;
    if (!isMiss && keeperColumn == target.column) {
      final saveChance = target.isTop ? highSaveChance : lowSaveChance;
      saved = _random.nextDouble() < saveChance;
    }

    final isGoal = !isMiss && !saved;
    final points =
        isGoal ? 100 + (target.isTop ? 50 : 0) + 25 * currentStreak : 0;

    return ShotOutcome(
      target: target,
      keeperZone: keeperZone,
      isGoal: isGoal,
      isMiss: isMiss,
      points: points,
    );
  }
}
