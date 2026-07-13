import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/shoot_logo.dart';
import '../logic/penalty_engine.dart';
import '../services/game_score_service.dart';
import '../widgets/game_graphics.dart';

/// شاشة لعبة ضربات الترجيح
///
/// [engine] قابل للتمرير من الاختبارات حتى تكون النتائج قابلة للتكرار.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.engine});

  final PenaltyEngine? engine;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late final PenaltyEngine _engine = widget.engine ?? PenaltyEngine();

  /// حركة الكرة والحارس بنفس الوقت
  late final AnimationController _shot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  /// هزة الشاشة وقت الگول — إحساس "ارتجاج الشبكة"
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// ظهور نص النتيجة (گول/صدة) — يبدي بعد ما توصل الكرة
  late final AnimationController _callout = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  final List<ShotOutcome> _outcomes = [];
  ShotOutcome? _current;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  bool _finished = false;

  @override
  void dispose() {
    _shot.dispose();
    _shake.dispose();
    _callout.dispose();
    super.dispose();
  }

  Future<void> _shoot(GoalZone zone) async {
    if (_current != null || _finished) return;

    final outcome = _engine.shoot(zone, currentStreak: _streak);
    setState(() => _current = outcome);
    _shot.forward(from: 0);

    // نص النتيجة والهزة يصيرون لحظة وصول الكرة، مو قبلها
    unawaited(
      Future.delayed(const Duration(milliseconds: 380)).then((_) {
        if (!mounted) return;
        _callout.forward(from: 0);
        if (outcome.isGoal) _shake.forward(from: 0);
      }),
    );

    // نخلي النتيجة تبين شوية قبل ما ننتقل للضربة الجاية
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() {
      _outcomes.add(outcome);
      if (outcome.isGoal) {
        _score += outcome.points;
        _streak++;
        _bestStreak = math.max(_bestStreak, _streak);
      } else {
        _streak = 0;
      }
      _current = null;
      _shot.reset();
      _callout.reset();

      if (_outcomes.length >= PenaltyEngine.shotsPerGame) {
        _finished = true;
        GameScoreService.instance.saveResult(
          GameResult(
            score: _score,
            goals: _outcomes.where((o) => o.isGoal).length,
            bestStreak: _bestStreak,
          ),
        );
      }
    });
  }

  void _restart() {
    setState(() {
      _outcomes.clear();
      _current = null;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _finished = false;
      _shot.reset();
      _callout.reset();
      _shake.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkFixed,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // موقع المرمى على الشاشة
          final goalWidth = math.min(w * 0.86, 420.0);
          final goalHeight = goalWidth * 0.42;
          final goalLeft = (w - goalWidth) / 2;
          final goalTop = h * 0.155;

          Offset zoneCenter(GoalZone zone) => Offset(
                goalLeft + (zone.column + 0.5) * goalWidth / 3,
                goalTop + (zone.row + 0.5) * goalHeight / 2,
              );

          final ballStart = Offset(w / 2, h * 0.86);
          final keeperW = goalWidth * 0.26;
          final keeperH = goalHeight * 0.95;

          // هزة خفيفة تخبو تدريجياً وقت الگول
          return AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 4) * 5 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Stack(
            children: [
              // الملعب
              const Positioned.fill(
                child: CustomPaint(painter: StadiumPainter()),
              ),
              // المرمى
              Positioned(
                left: goalLeft,
                top: goalTop,
                width: goalWidth,
                height: goalHeight,
                child: const CustomPaint(painter: GoalPainter()),
              ),
              // الحارس — واگف بالنص، ومع التسديدة ينط لمنطقته
              AnimatedBuilder(
                animation: _shot,
                builder: (context, child) {
                  final t = Curves.easeOutQuart.transform(_shot.value);
                  final outcome = _current;
                  final standCenter = Offset(
                    w / 2,
                    goalTop + goalHeight - keeperH / 2,
                  );
                  var center = standCenter;
                  var angle = 0.0;
                  if (outcome != null) {
                    final diveTo = zoneCenter(outcome.keeperZone);
                    center = Offset.lerp(standCenter, diveTo, t)!;
                    final dir =
                        (diveTo.dx - standCenter.dx).sign; // -1 يسار +1 يمين
                    angle = dir * 1.1 * t;
                  }
                  return Positioned(
                    left: center.dx - keeperW / 2,
                    top: center.dy - keeperH / 2,
                    width: keeperW,
                    height: keeperH,
                    child: Transform.rotate(
                      angle: angle,
                      child: CustomPaint(
                        painter: KeeperPainter(armsUp: outcome != null),
                      ),
                    ),
                  );
                },
              ),
              // الكرة — من نقطة الجزاء باتجاه المنطقة المختارة
              AnimatedBuilder(
                animation: _shot,
                builder: (context, child) {
                  final outcome = _current;
                  final t = Curves.easeOutCubic.transform(_shot.value);
                  var pos = ballStart;
                  var ballSize = w * 0.11;
                  if (outcome != null) {
                    var end = zoneCenter(outcome.target);
                    if (outcome.isMiss) {
                      // برا: فوگ العارضة
                      end = end.translate(
                        outcome.target.column == 0 ? -goalWidth * 0.12 : goalWidth * 0.12,
                        -goalHeight * 0.55,
                      );
                    }
                    pos = Offset.lerp(ballStart, end, t)!;
                    // قوس بسيط بالطيران + تصغير مع البعد
                    pos = pos.translate(0, -math.sin(t * math.pi) * h * 0.04);
                    ballSize = ballSize * (1 - 0.55 * t);
                  }
                  // الكرة تبرم أثناء الطيران — باتجاه التسديدة
                  final spinDir = outcome == null
                      ? 1.0
                      : (outcome.target.column - 1).clamp(-1, 1).toDouble();
                  return Positioned(
                    left: pos.dx - ballSize / 2,
                    top: pos.dy - ballSize / 2,
                    child: Transform.rotate(
                      angle: t * math.pi * 2.5 * (spinDir == 0 ? 1 : spinDir),
                      child: ShootMark(size: ballSize),
                    ),
                  );
                },
              ),
              // مناطق التسديد — تظهر كدوائر هدف خفيفة قبل الضربة
              if (_current == null && !_finished)
                for (final zone in GoalZone.values)
                  Positioned(
                    left: zoneCenter(zone).dx - goalWidth / 6 + 4,
                    top: zoneCenter(zone).dy - goalHeight / 4 + 4,
                    width: goalWidth / 3 - 8,
                    height: goalHeight / 2 - 8,
                    child: GestureDetector(
                      key: Key('zone-${zone.name}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _shoot(zone),
                      child: Center(
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.7),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              // الشريط العلوي: رجوع + النقاط + مؤشرات الضربات
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            Text(
                              '${AppStrings.gamePointsLabel}: $_score',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                for (var i = 0;
                                    i < PenaltyEngine.shotsPerGame;
                                    i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    child: _ShotDot(
                                      outcome: i < _outcomes.length
                                          ? _outcomes[i]
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        // موازنة بصرية لزر الرجوع
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ),
              ),
              // نص النتيجة — يظهر بنطّة لحظة وصول الكرة (من 0.9 مو من الصفر)
              if (_current != null)
                Positioned(
                  top: h * 0.46,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _callout,
                    builder: (context, child) {
                      final t =
                          Curves.easeOutBack.transform(_callout.value);
                      return Opacity(
                        opacity: _callout.value.clamp(0, 1),
                        child: Transform.scale(
                          scale: 0.9 + 0.1 * t,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          _current!.isGoal
                              ? AppStrings.goalCall
                              : _current!.isMiss
                                  ? AppStrings.missCall
                                  : AppStrings.savedCall,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _current!.isGoal
                                ? AppColors.accent
                                : AppColors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 12),
                            ],
                          ),
                        ),
                        if (_current!.isGoal)
                          Text(
                            '+${_current!.points}',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              // تلميح التسديد
              if (_current == null && !_finished)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Text(
                    AppStrings.gameHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              // شاشة النتيجة النهائية — تدخل بنعومة بدل الظهور المفاجئ
              if (_finished)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.96 + 0.04 * t,
                        child: child,
                      ),
                    ),
                    child: _ResultOverlay(
                      score: _score,
                      goals: _outcomes.where((o) => o.isGoal).length,
                      bestStreak: _bestStreak,
                      onReplay: _restart,
                      onExit: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
            ],
            ),
          );
        },
      ),
    );
  }
}

/// مؤشر ضربة بالشريط العلوي: فاضي = جاية، أخضر = گول، رمادي = ضاعت
class _ShotDot extends StatelessWidget {
  const _ShotDot({this.outcome});

  final ShotOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: o == null
            ? Colors.transparent
            : o.isGoal
                ? AppColors.primary
                : AppColors.grey,
        border: Border.all(
          color: o == null
              ? AppColors.white.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: o == null
          ? null
          : Icon(
              o.isGoal ? Icons.check_rounded : Icons.close_rounded,
              size: 11,
              color: AppColors.white,
            ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: AppColors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// نتيجة الجولة — تقييم ونقاط وزر إعادة
class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.score,
    required this.goals,
    required this.bestStreak,
    required this.onReplay,
    required this.onExit,
  });

  final int score;
  final int goals;
  final int bestStreak;
  final VoidCallback onReplay;
  final VoidCallback onExit;

  String get _rating => switch (goals) {
        5 => AppStrings.rating5,
        4 => AppStrings.rating4,
        3 => AppStrings.rating3,
        2 => AppStrings.rating2,
        _ => AppStrings.rating01,
      };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.gameOverTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _rating,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _ResultStat(
                    value: '$score',
                    label: AppStrings.gamePointsLabel,
                  ),
                  _ResultStat(
                    value: '$goals/${PenaltyEngine.shotsPerGame}',
                    label: AppStrings.goalsLabel,
                  ),
                  _ResultStat(
                    value: '$bestStreak',
                    label: AppStrings.bestStreakLabel,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${AppStrings.sessionBestLabel}: '
                '${GameScoreService.instance.bestScore}',
                style: TextStyle(
                  color: AppColors.grey,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              // ⚓ هنا مستقبلاً يصير زر "بدّل نقاطك بخصم" (GameScoreService)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppStrings.rewardTeaser,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppColors.dark,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onReplay,
                child: const Text(AppStrings.playAgain),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onExit,
                child: const Text(AppStrings.exitGame),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: AppColors.primaryDeep,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
