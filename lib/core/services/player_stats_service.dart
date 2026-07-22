import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/player_stats.dart';
import 'bookings_service.dart';
import 'cancellations_service.dart';
import 'request_responses_service.dart';

/// يجمع إحصائيات لاعب من كل الخدمات المعنية — كل رقم مشتق من مستندات
/// حقيقية (حجوزات، إلغاءات، انضمامات) عبر عدّ مجمّع، صفر بيانات وهمية.
class PlayerStatsService {
  PlayerStatsService._();

  static final PlayerStatsService instance = PlayerStatsService._();

  bool get _useMock => Firebase.apps.isEmpty;

  /// إحصائيات وشارات لاعب معيّن — تصلح لملفي الشخصي أو ملف لاعب ثاني
  Future<PlayerStats> statsFor(String uid) async {
    if (uid.isEmpty) {
      return const PlayerStats(
        matchesPlayed: 0,
        gapsFilled: 0,
        selfCancellations: 0,
        hasEverBooked: false,
      );
    }

    final results = await Future.wait([
      BookingsService.instance.matchesPlayedCount(uid),
      BookingsService.instance.totalBookingsCount(uid),
      BookingsService.instance.selfCancellationsCount(uid),
      RequestResponsesService.instance.gapsFilledCount(uid),
      CancellationsService.instance.cancelledAgainstCount(uid),
    ]);

    final matchesPlayed = results[0];
    final totalBookings = results[1];
    final selfCancellations = results[2];
    final gapsFilled = results[3];
    final cancelledAgainst = results[4];

    return PlayerStats(
      matchesPlayed: matchesPlayed,
      gapsFilled: gapsFilled,
      selfCancellations: selfCancellations,
      // حجز ولو مرة وحدة: إما عنده حجز حالياً، أو انلغى حجزه (بنفسه أو
      // من صاحب الملعب) — الحالتين تثبتان وجود حجز حقيقي سابق.
      hasEverBooked:
          totalBookings > 0 || selfCancellations > 0 || cancelledAgainst > 0,
    );
  }

  /// الملف العام للاعب (اسم، مدينة، صورة، مدة عضوية) من مجموعة players —
  /// null إذا ما توفر (بعده ما أنشأ ملفه، أو وضع التجربة)
  Future<PublicPlayerProfile?> publicProfile(String uid) async {
    if (_useMock || uid.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('players')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      final data = snap.data();
      if (data == null) return null;
      final createdAt = data['createdAt'];
      return PublicPlayerProfile(
        name: (data['name'] as String?) ?? '',
        city: (data['city'] as String?) ?? '',
        photoUrl: (data['photoUrl'] as String?) ?? '',
        joinedAtMs: createdAt is Timestamp
            ? createdAt.millisecondsSinceEpoch
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}
