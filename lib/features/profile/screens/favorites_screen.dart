import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/field_card.dart';

/// شاشة المفضلة — الملاعب اللي حط عليها المستخدم قلب
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.favoritesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // نسمع تغييرات المفضلة حتى الإزالة من هنا تحدّث القائمة فوراً
      body: ValueListenableBuilder<int>(
        valueListenable: UserService.instance.revision,
        builder: (context, _, _) {
          final favoriteIds = UserService.instance.favoriteIds;
          final fields = FieldsService.instance
              .search()
              .where((f) => favoriteIds.contains(f.id))
              .toList();

          if (fields.isEmpty) {
            return Center(
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
                        Icons.favorite_border_rounded,
                        size: 48,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.noFavoritesTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.noFavoritesMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.grey,
                            fontWeight: FontWeight.w600,
                            height: 1.7,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            // سطر عدّاد فوق القائمة — المستخدم يعرف چم ملعب محفوظ
            itemCount: fields.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2, bottom: 2),
                  child: Text(
                    '${fields.length} ${AppStrings.favoritesCountUnit}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                );
              }
              return FieldCard(field: fields[i - 1]);
            },
          );
        },
      ),
    );
  }
}
