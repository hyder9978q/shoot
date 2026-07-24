import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/venue_suggestion.dart';
import '../../../core/services/venue_suggestions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';
import 'suggest_venue_screen.dart';

/// شاشة "اقتراحاتي" — كل ملعب اقترحه اللاعب (أو زاد صوته لاقتراح
/// موجود) مع حالته الحالية: قيد المراجعة / انضاف / مرفوض
class MyVenueSuggestionsScreen extends StatefulWidget {
  const MyVenueSuggestionsScreen({super.key});

  @override
  State<MyVenueSuggestionsScreen> createState() =>
      _MyVenueSuggestionsScreenState();
}

class _MyVenueSuggestionsScreenState extends State<MyVenueSuggestionsScreen> {
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
      final suggestions = await VenueSuggestionsService.instance
          .mySuggestions();
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (_) {
      if (mounted) setState(() => _suggestions = const []);
    }
  }

  Future<void> _addNew() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SuggestVenueScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.mySuggestionsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addNew,
          ),
        ],
      ),
      body: suggestions == null
          ? const Center(child: CircularProgressIndicator())
          : suggestions.isEmpty
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
                        Icons.stadium_outlined,
                        size: 48,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.noSuggestionsTitle,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.noSuggestionsMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey,
                        fontWeight: FontWeight.w600,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Pressable(
                      child: ElevatedButton.icon(
                        onPressed: _addNew,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(AppStrings.suggestVenueCta),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _SuggestionCard(suggestion: suggestions[i]),
            ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final VenueSuggestion suggestion;

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
            children: [
              Expanded(
                child: Text(
                  suggestion.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.dark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  suggestion.area,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          if (suggestion.requestCount > 1) ...[
            const SizedBox(height: 8),
            Text(
              AppStrings.suggestionRequestersLabel(suggestion.requestCount),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
