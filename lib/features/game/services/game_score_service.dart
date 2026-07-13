import 'package:flutter/foundation.dart';

import '../logic/penalty_engine.dart';

/// خدمة نقاط اللعبة — حالياً بالذاكرة فقط.
///
/// ⚓ نقطة الربط المستقبلي (خصم على الحجز):
/// من نقرر نفعّل "بدّل نقاطك بخصم"، هاي الخدمة هي المكان الوحيد اللي يتغيّر:
/// 1. [saveResult] تكتب النقاط بـ Firestore: `users/{uid}/gameStats`
///    (rules: القراءة والكتابة لصاحب الحساب فقط).
/// 2. نضيف دالة `redeemPoints(int points)` تنقص النقاط وترجع قيمة الخصم،
///    وشاشة تأكيد الحجز تستدعيها قبل حساب العربون.
/// 3. `totalPoints` تصير تنقرأ من Firestore بدل الذاكرة.
/// كل شاشات اللعبة تتعامل وياها عبر هاي الواجهة، فالربط ما يلمس اللعبة نفسها.
class GameScoreService {
  GameScoreService._();

  static final GameScoreService instance = GameScoreService._();

  /// يتحدث مع كل نتيجة جديدة — للشاشات اللي تعرض النقاط
  final ValueNotifier<int> revision = ValueNotifier(0);

  int _bestScore = 0;
  int _totalPoints = 0;

  /// أعلى نتيجة بجولة وحدة (بهاي الجلسة)
  int get bestScore => _bestScore;

  /// مجموع النقاط المتراكمة — هاي اللي راح تنبدل بخصومات مستقبلاً
  int get totalPoints => _totalPoints;

  void saveResult(GameResult result) {
    _totalPoints += result.score;
    if (result.score > _bestScore) _bestScore = result.score;
    revision.value++;
  }
}
