import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/venue_suggestion.dart';
import '../../../core/services/venue_suggestions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_num.dart';
import '../../../core/widgets/pressable.dart';

/// لوحة إدارة اقتراحات الملاعب — للمسؤول فقط (يتحقق منه main_shell قبل
/// ما يفتح هذي الشاشة، وقواعد Firestore تمنع أي حد ثاني من قراءتها).
/// كل الاقتراحات مرتّبة بعدد الطلبات — الأكثر طلباً أولاً، حتى يعرف
/// المسؤول أي ملعب يسجّله أول.
class AdminVenueSuggestionsScreen extends StatefulWidget {
  const AdminVenueSuggestionsScreen({super.key});

  @override
  State<AdminVenueSuggestionsScreen> createState() =>
      _AdminVenueSuggestionsScreenState();
}

class _AdminVenueSuggestionsScreenState
    extends State<AdminVenueSuggestionsScreen> {
  List<VenueSuggestion>? _suggestions;

  @override
  void initState() {
    super.initState();
    _load();
    VenueSuggestionsService.instance.revision.addListener(_load);
  }

  @override
  void dispose() {
    VenueSuggestionsService.instance.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = await VenueSuggestionsService.instance.allSuggestions();
      if (mounted) setState(() => _suggestions = all);
    } catch (_) {
      if (mounted) setState(() => _suggestions = const []);
    }
  }

  Future<void> _changeStatus(
    VenueSuggestion suggestion,
    VenueSuggestionStatus status,
  ) async {
    try {
      await VenueSuggestionsService.instance.updateStatus(suggestion, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.adminStatusUpdated)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.adminStatusUpdateError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.adminSuggestionsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: suggestions == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: suggestions.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                            child: Text(
                              AppStrings.adminNoSuggestions,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                      itemCount: suggestions.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Text(
                            AppStrings.adminSuggestionsSubtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          );
                        }
                        final suggestion = suggestions[i - 1];
                        return _AdminSuggestionCard(
                          suggestion: suggestion,
                          rank: i,
                          onStatusChange: (status) =>
                              _changeStatus(suggestion, status),
                        );
                      },
                    ),
            ),
    );
  }
}

class _AdminSuggestionCard extends StatelessWidget {
  const _AdminSuggestionCard({
    required this.suggestion,
    required this.rank,
    required this.onStatusChange,
  });

  final VenueSuggestion suggestion;
  final int rank;
  final ValueChanged<VenueSuggestionStatus> onStatusChange;

  Color _statusColor() => switch (suggestion.status) {
    VenueSuggestionStatus.pending => AppColors.accentInk,
    VenueSuggestionStatus.added => AppColors.primaryDark,
    VenueSuggestionStatus.rejected => AppColors.error,
  };

  Color _statusBg() => switch (suggestion.status) {
    VenueSuggestionStatus.pending => AppColors.accentSoft,
    VenueSuggestionStatus.added => AppColors.primaryTint,
    VenueSuggestionStatus.rejected => AppColors.errorSoft,
  };

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ترتيب حسب عدد الطلبات
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ArabicNum.count(rank),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            suggestion.area,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      ArabicNum.count(suggestion.requestCount),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentInk,
                      ),
                    ),
                    Text(
                      AppStrings.adminRequestCountUnit,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (suggestion.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                suggestion.note,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (suggestion.mapsUrl.isNotEmpty || suggestion.phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (suggestion.mapsUrl.isNotEmpty)
                  _ActionChip(
                    icon: Icons.map_outlined,
                    label: AppStrings.adminOpenMaps,
                    onTap: () => launchUrl(
                      Uri.parse(suggestion.mapsUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                if (suggestion.phone.isNotEmpty)
                  _ActionChip(
                    icon: Icons.call_outlined,
                    label: AppStrings.adminCallVenue,
                    onTap: () => launchUrl(Uri.parse('tel:${suggestion.phone}')),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusBg(),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  suggestion.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _statusColor(),
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<VenueSuggestionStatus>(
                onSelected: onStatusChange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                itemBuilder: (context) => [
                  for (final status in VenueSuggestionStatus.values)
                    PopupMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          if (status == suggestion.status)
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.primary,
                            )
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 6),
                          Text(
                            status.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 14, color: AppColors.white),
                      const SizedBox(width: 5),
                      Text(
                        AppStrings.adminChangeStatusAction,
                        style: TextStyle(
                          fontSize: 12,
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
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryDark),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
