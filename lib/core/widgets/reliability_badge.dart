import 'package:flutter/material.dart';

import '../constants/app_features.dart';
import '../constants/app_strings.dart';
import '../models/cancellation.dart';
import '../services/cancellations_service.dart';
import '../theme/app_colors.dart';
import '../utils/arabic_num.dart';

/// مؤشر التزام الملعب — يساعد اللاعب يميّز الملاعب الجادة.
///
/// ما نعرض رقم إلا إذا عند الملعب تاريخ كافي ([FieldReliability.minSample])،
/// لأن نسبة مبنية على حجزين تضلل أكثر ما تفيد.
class ReliabilityBadge extends StatefulWidget {
  const ReliabilityBadge({super.key, required this.fieldId});

  final String fieldId;

  @override
  State<ReliabilityBadge> createState() => _ReliabilityBadgeState();
}

class _ReliabilityBadgeState extends State<ReliabilityBadge> {
  FieldReliability? _reliability;

  @override
  void initState() {
    super.initState();
    _load();
    CancellationsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    CancellationsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!AppFeatures.showFieldReliability) return;
    try {
      final value =
          await CancellationsService.instance.reliabilityFor(widget.fieldId);
      if (mounted) setState(() => _reliability = value);
    } catch (_) {
      // ما نعرض شي بدل ما نعرض رقم غلط
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _reliability;
    if (!AppFeatures.showFieldReliability || value == null) {
      return const SizedBox.shrink();
    }
    if (!value.hasEnoughData) return const SizedBox.shrink();

    final good = value.isReliable;
    final risky = value.isRisky;
    final color = good
        ? AppColors.primary
        : risky
            ? AppColors.error
            : AppColors.star;

    // Align يمنعها من التمدد لو الأب crossAxisAlignment.stretch
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        // المسافة العلوية جزء من الشارة — وهي مخفية ما تترك فراغ
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              good
                  ? Icons.verified_rounded
                  : risky
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.reliabilityValue(ArabicNum.count(value.percent)),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  good
                      ? AppStrings.reliabilityGood
                      : risky
                          ? AppStrings.reliabilityRisky
                          : AppStrings.reliabilityTooltip(
                              ArabicNum.count(value.kept),
                              ArabicNum.count(value.cancelled),
                            ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
