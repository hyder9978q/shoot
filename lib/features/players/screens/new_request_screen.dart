import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/player_requests_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable.dart';

/// نموذج نشر إعلان "ناقصنا لاعب"
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _placeController = TextEditingController();
  final _noteController = TextEditingController();

  Sport _sport = Sport.football;
  int? _hour;
  int _playersNeeded = 1;
  String? _placeError;
  bool _posting = false;

  @override
  void dispose() {
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final place = _placeController.text.trim();
    if (place.isEmpty) {
      setState(() => _placeError = AppStrings.placeError);
      return;
    }
    if (_hour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.timeError)),
      );
      return;
    }

    setState(() {
      _placeError = null;
      _posting = true;
    });
    try {
      await PlayerRequestsService.instance.createRequest(
        sport: _sport,
        place: place,
        hour: _hour!,
        playersNeeded: _playersNeeded,
        note: _noteController.text,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.requestPostError)),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.requestPosted)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.playersTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // شريط سفلي ثابت — الزر دائماً بمتناول الإبهام
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
            child: Pressable(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: AppColors.primaryShadow,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: ElevatedButton(
                  onPressed: _posting ? null : _post,
                  child: _posting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(AppStrings.postRequest),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        children: [
          // الرياضة
          Text(AppStrings.sportLabel, style: labelStyle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sport in Sport.values)
                _ChoiceChip(
                  label: sport.label,
                  icon: sport.icon,
                  selected: _sport == sport,
                  onTap: () => setState(() => _sport = sport),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // المكان
          Text(AppStrings.placeLabel, style: labelStyle),
          const SizedBox(height: 10),
          TextField(
            controller: _placeController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: AppStrings.placeHint,
              errorText: _placeError,
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // الوقت
          Text(AppStrings.timeLabel2, style: labelStyle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var h = 16; h < 24; h++)
                _ChoiceChip(
                  label: '${h.toString().padLeft(2, '0')}:00',
                  ltr: true,
                  selected: _hour == h,
                  onTap: () => setState(() => _hour = h),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // چم لاعب
          Text(AppStrings.playersNeededLabel, style: labelStyle),
          const SizedBox(height: 10),
          // العداد داخل حاوية بيضاء — كتلة وحدة بدل أزرار سايحة
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // بالعربي الاتجاه معكوس: الزيادة تجي بجهة البداية (اليمين)
                _StepButton(
                  icon: Icons.add_rounded,
                  enabled: _playersNeeded < 5,
                  onTap: () => setState(() => _playersNeeded++),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$_playersNeeded',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDeep,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        AppStrings.playersUnit,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StepButton(
                  icon: Icons.remove_rounded,
                  enabled: _playersNeeded > 1,
                  onTap: () => setState(() => _playersNeeded--),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ملاحظة
          Text(AppStrings.noteLabel, style: labelStyle),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLines: 2,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: AppStrings.noteHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          // تنويه الرقم
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.primaryDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.contactNote,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark.withValues(alpha: 0.8),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شيب اختيار — نفس ستايل شيبس الفلترة بالرئيسية
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.ltr = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool ltr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: selected ? AppColors.primaryShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? AppColors.white : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    textDirection: ltr ? TextDirection.ltr : null,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: selected ? AppColors.white : AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر زيادة/نقصان عدد اللاعبين
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: Material(
        color: enabled ? AppColors.primaryLight : AppColors.subtleFill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              size: 26,
              color: enabled ? AppColors.primaryDeep : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
