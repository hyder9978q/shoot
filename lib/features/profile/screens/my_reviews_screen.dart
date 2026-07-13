import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/review.dart';
import '../../../core/services/reviews_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/rating_stars.dart';

/// شاشة تقييماتي — كل تقييماتي مع إمكانية الحذف
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<Review>? _reviews;

  @override
  void initState() {
    super.initState();
    _load();
    ReviewsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    ReviewsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final reviews = await ReviewsService.instance.myReviews();
      if (mounted) setState(() => _reviews = reviews);
    } catch (_) {
      if (mounted) setState(() => _reviews = const []);
    }
  }

  Future<void> _delete(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteReviewTitle),
        content: const Text(
          AppStrings.deleteReviewConfirm,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
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
      await ReviewsService.instance.deleteReview(review);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.reviewDeleted)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.reviewError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.myReviewsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: reviews == null
          ? ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, _) => const _ReviewSkeleton(),
            )
          : reviews.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            Icons.star_outline_rounded,
                            size: 48,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.noMyReviewsTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.noMyReviewsMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.grey,
                                fontWeight: FontWeight.w600,
                                height: 1.7,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  itemCount: reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => _ReviewCard(
                    review: reviews[i],
                    onDelete: () => _delete(reviews[i]),
                  ),
                ),
    );
  }
}

/// بطاقة تقييم — النجوم بالأعلى، الحذف بذيل بحد رفيع (نفس بطاقة الحجز)
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onDelete});

  final Review review;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.fieldName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.dark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RatingStars(rating: review.rating),
                  ],
                ),
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      review.comment,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppColors.grey,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Pressable(
              onTap: onDelete,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.deleteReviewTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// هيكل تحميل بطاقة تقييم
class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double width, double height, [double radius = 8]) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.subtleFill,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              block(130, 15),
              block(80, 14),
            ],
          ),
          const SizedBox(height: 14),
          block(double.infinity, 40, 12),
        ],
      ),
    );
  }
}
