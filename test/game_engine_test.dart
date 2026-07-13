import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoot/features/game/logic/penalty_engine.dart';

void main() {
  group('محرك ضربات الترجيح', () {
    test('نفس البذرة تعطي نفس النتائج (قابل للتكرار)', () {
      final a = PenaltyEngine(random: Random(42));
      final b = PenaltyEngine(random: Random(42));
      for (var i = 0; i < 20; i++) {
        final zone = GoalZone.values[i % GoalZone.values.length];
        final oa = a.shoot(zone);
        final ob = b.shoot(zone);
        expect(oa.isGoal, ob.isGoal);
        expect(oa.keeperZone, ob.keeperZone);
        expect(oa.points, ob.points);
      }
    });

    test('التسديد بعيد عن عمود الحارس = گول دائماً (بالضربات الواطية)', () {
      final engine = PenaltyEngine(random: Random(1));
      for (var i = 0; i < 500; i++) {
        final o = engine.shoot(GoalZone.bottomLeft);
        if (o.keeperZone.column != GoalZone.bottomLeft.column) {
          expect(o.isGoal, isTrue,
              reason: 'الحارس بعمود ثاني — لازم تكون گول');
        }
      }
    });

    test('نسبة الأهداف بالضربة الواطية منطقية (~72%)', () {
      final engine = PenaltyEngine(random: Random(2));
      var goals = 0;
      const trials = 2000;
      for (var i = 0; i < trials; i++) {
        if (engine.shoot(GoalZone.bottomCenter).isGoal) goals++;
      }
      final ratio = goals / trials;
      expect(ratio, greaterThan(0.62));
      expect(ratio, lessThan(0.82));
    });

    test('الزوايا العالية ممكن تطلع برا، والواطية أبداً', () {
      final engine = PenaltyEngine(random: Random(3));
      var topMisses = 0;
      for (var i = 0; i < 1000; i++) {
        if (engine.shoot(GoalZone.topRight).isMiss) topMisses++;
        expect(engine.shoot(GoalZone.bottomRight).isMiss, isFalse);
        expect(engine.shoot(GoalZone.topCenter).isMiss, isFalse);
      }
      expect(topMisses, greaterThan(0));
      expect(topMisses / 1000, lessThan(0.2));
    });

    test('النقاط: 100 واطية، 150 عالية، +25 لكل هدف بالسلسلة', () {
      final engine = PenaltyEngine(random: Random(4));

      ShotOutcome goalAt(GoalZone zone, int streak) {
        while (true) {
          final o = engine.shoot(zone, currentStreak: streak);
          if (o.isGoal) return o;
        }
      }

      expect(goalAt(GoalZone.bottomLeft, 0).points, 100);
      expect(goalAt(GoalZone.topLeft, 0).points, 150);
      expect(goalAt(GoalZone.bottomCenter, 2).points, 150);
      expect(goalAt(GoalZone.topRight, 3).points, 225);
    });

    test('الصدة تعطي صفر نقاط', () {
      final engine = PenaltyEngine(random: Random(5));
      for (var i = 0; i < 500; i++) {
        final o = engine.shoot(GoalZone.bottomCenter, currentStreak: 4);
        if (!o.isGoal) expect(o.points, 0);
      }
    });
  });
}
