import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/leaderboard_entry.dart';
import '../../../core/services/bookings_service.dart';
import '../../../core/services/leaderboard_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/widgets/pressable.dart';
import 'player_profile_screen.dart';

/// ترتيب الحي/المدينة — أنشط اللاعبين بنفس مدينة المستخدم هذا الشهر،
/// محسوب من حجوزات حقيقية فقط. يتحدّث تلقائياً مع أي حجز/إلغاء جديد.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardResult? _result;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
    BookingsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    BookingsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final city = UserService.instance.city;
    if (city.isEmpty) {
      if (mounted) setState(() => _result = LeaderboardResult.empty);
      return;
    }
    try {
      final result = await LeaderboardService.instance.monthly(city);
      if (mounted) {
        setState(() {
          _result = result;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _openProfile(LeaderboardEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlayerProfileScreen(uid: entry.userId, initialName: entry.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = UserService.instance.city;
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.leaderboardTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: city.isEmpty
          ? _NeedsCityState(onDone: _load)
          : result == null
          ? _error
                ? _ErrorState(onRetry: _load)
                : const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                children: [
                  Text(
                    AppStrings.leaderboardSubtitle(city),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (result.top.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Text(
                        AppStrings.leaderboardEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey,
                          height: 1.7,
                        ),
                      ),
                    )
                  else
                    for (final entry in result.top)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LeaderboardRow(
                          entry: entry,
                          isMe: entry.userId == UserService.instance.uid,
                          onTap: () => _openProfile(entry),
                        ),
                      ),
                  if (result.myRank > LeaderboardService.topSize) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            AppStrings.yourRank(ArabicNum.count(result.myRank)),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${ArabicNum.count(result.myMatches)} ${AppStrings.matchesPlayedWord}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (result.myRank == 0 && result.top.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        AppStrings.notRankedYet,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final medal = switch (entry.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };

    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
          border: isMe
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                medal ?? ArabicNum.count(entry.rank),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: medal != null ? 18 : 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.name.isEmpty ? AppStrings.guestName : entry.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            Text(
              '${ArabicNum.count(entry.matchesThisMonth)} ${AppStrings.matchesPlayedWord}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedsCityState extends StatelessWidget {
  const _NeedsCityState({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: AppColors.primaryDark,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.leaderboardNeedsCity,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 20),
            Pressable(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => PlayerProfileScreen(
                            uid: UserService.instance.uid,
                            isOwn: true,
                          ),
                        ),
                      )
                      .then((_) => onDone());
                },
                child: const Text(AppStrings.pickCity),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppStrings.profileLoadError,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Pressable(
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
