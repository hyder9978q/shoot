import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/ad.dart';
import '../../../core/models/field.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/widgets/pressable.dart';
import 'ad_form_screen.dart';

/// تبويب "إعلاناتي" — كل إعلانات صاحب الحساب عبر منشآته، وزر نشر
/// إعلان جديد. يقدر يعدّل، يوقف/يفعّل، أو يحذف أي إعلان له.
class OwnerAdsScreen extends StatefulWidget {
  const OwnerAdsScreen({super.key, required this.fields});

  final List<Field> fields;

  @override
  State<OwnerAdsScreen> createState() => _OwnerAdsScreenState();
}

class _OwnerAdsScreenState extends State<OwnerAdsScreen> {
  List<Ad>? _ads;

  @override
  void initState() {
    super.initState();
    _load();
    AdsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    AdsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OwnerAdsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fields.length != widget.fields.length) _load();
  }

  Future<void> _load() async {
    final ids = [for (final f in widget.fields) f.id];
    final ads = await AdsService.instance.myAds(ids);
    if (mounted) setState(() => _ads = ads);
  }

  Future<void> _addAd() async {
    if (widget.fields.isEmpty) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdFormScreen(fields: widget.fields),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _editAd(Ad ad) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdFormScreen(fields: widget.fields, existing: ad),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _toggleActive(Ad ad) async {
    try {
      await AdsService.instance.setActive(ad, !ad.isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ad.isActive ? AppStrings.adPaused : AppStrings.adResumed),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.adActionError)),
      );
    }
  }

  Future<void> _deleteAd(Ad ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteAdTitle),
        content: const Text(AppStrings.deleteAdConfirm),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.yesDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await AdsService.instance.deleteAdWithImage(ad);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.adDeleted)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.adActionError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ads = _ads;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.myAdsTitle),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: Pressable(
              onTap: _addAd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 17, color: AppColors.white),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.addAdAction,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ads == null
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ads.isEmpty
          ? _EmptyAds(onAdd: _addAd)
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                itemCount: ads.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _AdCard(
                    ad: ads[i],
                    onTap: () => _editAd(ads[i]),
                    onToggle: () => _toggleActive(ads[i]),
                    onDelete: () => _deleteAd(ads[i]),
                  ),
                ),
              ),
            ),
    );
  }
}

class _EmptyAds extends StatelessWidget {
  const _EmptyAds({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 56, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              AppStrings.noAdsTitle,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.noAdsMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Pressable(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.primaryShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 18, color: AppColors.white),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.addAdAction,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({
    required this.ad,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final Ad ad;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final today = DateLabels.dateFor(0);
    final expired = ad.isExpiredAt(today);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            onTap: onTap,
            child: Row(
              children: [
                if (ad.imageUrl.isNotEmpty)
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CachedNetworkImage(
                      imageUrl: ad.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    color: AppColors.primaryTint,
                    child: Icon(
                      ad.type.icon,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(ad.type.icon, size: 13, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              ad.type.label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ad.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ad.fieldName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (expired)
                              _Badge(
                                label: AppStrings.adExpiredBadge,
                                color: AppColors.error,
                                bg: AppColors.errorSoft,
                              )
                            else if (!ad.isActive)
                              _Badge(
                                label: AppStrings.adPausedBadge,
                                color: AppColors.grey,
                                bg: AppColors.subtleFill,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.hairline),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: expired ? null : onToggle,
                  icon: Icon(
                    ad.isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text(
                    ad.isActive
                        ? AppStrings.pauseAdAction
                        : AppStrings.resumeAdAction,
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: AppColors.hairline),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(AppStrings.deleteAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.bg});

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
