import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/player_stats.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/services/player_stats_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/widgets/pressable.dart';

/// ملف اللاعب — صورة، اسم، مدينة، إحصائيات وشارات كلها محسوبة من بيانات
/// حقيقية بـ Firestore (صفر بيانات وهمية، نفس مبدأ مؤشر الموثوقية).
///
/// [isOwn] تفتح تعديل الصورة والمدينة. لغير صاحب الملف نعرض بس القراءة،
/// من نسخة عامة آمنة بمجموعة players (بدون رقم هاتف ولا مفضلة).
class PlayerProfileScreen extends StatefulWidget {
  const PlayerProfileScreen({
    super.key,
    required this.uid,
    this.isOwn = false,
    this.initialName = '',
  });

  final String uid;
  final bool isOwn;

  /// اسم أولي (من ترتيب الحي مثلاً) — يبين ريثما يتحمّل الملف كامل
  final String initialName;

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  PlayerStats? _stats;
  PublicPlayerProfile? _publicProfile;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.isOwn) {
      UserService.instance.revision.addListener(_onOwnChanged);
    }
  }

  @override
  void dispose() {
    if (widget.isOwn) {
      UserService.instance.revision.removeListener(_onOwnChanged);
    }
    super.dispose();
  }

  void _onOwnChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final stats = await PlayerStatsService.instance.statsFor(widget.uid);
      final profile = widget.isOwn
          ? null
          : await PlayerStatsService.instance.publicProfile(widget.uid);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _publicProfile = profile;
        _error = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _pickCity() async {
    final cities = FieldsService.instance.cities;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                AppStrings.chooseCityTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final city in cities)
                    ListTile(
                      title: Text(
                        city,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: UserService.instance.city == city
                          ? Icon(Icons.check_rounded, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(city),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await UserService.instance.saveCity(selected);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.citySavedMsg)));
  }

  Future<void> _changePhoto() async {
    try {
      await UserService.instance.pickAndUploadPhoto();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.photoSaved)));
    } on InvalidImageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.tooLarge ? AppStrings.photoTooLarge : AppStrings.photoInvalidType,
          ),
        ),
      );
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.photosNeedLiveApp)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.photoUploadError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final own = widget.isOwn;
    final name = own
        ? (UserService.instance.name.isEmpty
              ? widget.initialName
              : UserService.instance.name)
        : ((_publicProfile?.name.isNotEmpty ?? false)
              ? _publicProfile!.name
              : widget.initialName);
    final city = own ? UserService.instance.city : (_publicProfile?.city ?? '');
    final photoUrl = own
        ? UserService.instance.photoUrl
        : (_publicProfile?.photoUrl ?? '');
    final joinedAtMs = own
        ? UserService.instance.joinedAtMs
        : _publicProfile?.joinedAtMs;
    final stats = _stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.playerProfileTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: stats == null
          ? _error
                ? _ErrorState(onRetry: _load)
                : const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _Avatar(name: name, photoUrl: photoUrl, size: 100),
                        if (own)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Pressable(
                              onTap: _changePhoto,
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppColors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      name.isEmpty ? AppStrings.guestName : name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Pressable(
                      onTap: own ? _pickCity : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              city.isEmpty
                                  ? (own ? AppStrings.pickCity : '')
                                  : city,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (joinedAtMs != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        DateLabels.membershipLabel(joinedAtMs),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _StatBox(
                        value: ArabicNum.count(stats.matchesPlayed),
                        label: AppStrings.matchesPlayedWord,
                      ),
                      const SizedBox(width: 12),
                      _StatBox(
                        value: ArabicNum.count(stats.gapsFilled),
                        label: AppStrings.gapsFilledWord,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    AppStrings.badgesTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final badge in PlayerBadge.values)
                        _BadgeChip(
                          badge: badge,
                          earned: stats.earnedBadges.contains(badge),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// أفاتار دائري — صورة حقيقية إذا متوفرة، وإلا حرف الاسم الأول
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  final String name;
  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '؟' : name.characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
        boxShadow: AppColors.cardShadow,
      ),
      child: photoUrl.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            )
          : CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              width: size,
              height: size,
              fadeInDuration: const Duration(milliseconds: 250),
              errorWidget: (_, _, _) => Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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

/// شارة واحدة — ملوّنة إذا محصّلة، رمادية بقفل إذا لا
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge, required this.earned});

  final PlayerBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final color = earned ? AppColors.primary : AppColors.muted;
    return Pressable(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(earned ? badge.description : AppStrings.badgeLocked),
        ),
      ),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: earned ? AppColors.primaryTint : AppColors.subtleFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: earned ? 1 : 0.35,
              child: Text(badge.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 8),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (!earned) ...[
              const SizedBox(height: 3),
              Icon(Icons.lock_rounded, size: 12, color: AppColors.muted),
            ],
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
