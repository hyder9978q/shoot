import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/ad.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../../fields/screens/field_details_screen.dart';

/// قسم "العروض والإعلانات" بالرئيسية — أحدث إعلانات صاحبات المنشآت
/// النشطة (غير الموقوفة وغير المنتهية)، تمرير أفقي. يختفي كلياً لو
/// ماكو إعلانات نشطة حالياً.
class AdsSection extends StatefulWidget {
  const AdsSection({super.key});

  @override
  State<AdsSection> createState() => _AdsSectionState();
}

class _AdsSectionState extends State<AdsSection> {
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

  Future<void> _load() async {
    final ads = await AdsService.instance.activeAds();
    if (mounted) setState(() => _ads = ads);
  }

  Future<void> _open(Ad ad) async {
    // نضمن الملاعب محمّلة كاملة حتى نلگى منشأة الإعلان لو ما وصلت
    // بالدفعة الأولى المعروضة بالرئيسية
    var field = FieldsService.instance.byId(ad.fieldId);
    if (field == null) {
      final all = await FieldsService.instance.loadAllFields();
      for (final f in all) {
        if (f.id == ad.fieldId) {
          field = f;
          break;
        }
      }
    }
    if (field == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FieldDetailsScreen(field: field!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ads = _ads;
    if (ads == null || ads.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Text(
            AppStrings.adsSectionTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            itemCount: ads.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                _AdCard(ad: ads[i], onTap: () => _open(ads[i])),
          ),
        ),
      ],
    );
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({required this.ad, required this.onTap});

  final Ad ad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 88,
              width: double.infinity,
              child: ad.imageUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: ad.imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primaryTint,
                      alignment: Alignment.center,
                      child: Icon(
                        ad.type.icon,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.type.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ad.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ad.fieldName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
