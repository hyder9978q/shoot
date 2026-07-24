import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/widgets/field_card.dart';
import '../../../core/widgets/pressable.dart';
import '../../game/screens/game_screen.dart';
import '../../map/screens/fields_map_screen.dart';
import '../../venues/screens/suggest_venue_screen.dart';
import '../widgets/ads_section.dart';
import '../widgets/play_now_section.dart';

/// تبويب الرئيسية — رأس أخضر + بحث + بلاطات الرياضات + بانر + الملاعب
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Sport? _selectedSport;

  /// المدينة المختارة — null = كل العراق
  String? _selectedCity;
  bool _loading = true;

  /// دخول متدرّج للبطاقات أول ما تتحمل (مرة وحدة فقط)
  late final AnimationController _stagger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    // أول دفعة فقط — الباقي يجي بالتمرير حتى تظهر الشاشة بسرعة
    FieldsService.instance.loadFields().then((_) {
      if (!mounted) return;
      setState(() => _loading = false);
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      reduceMotion ? _stagger.value = 1 : _stagger.forward();
    });
    // كل دفعة جديدة توصل → القائمة تتحدث
    FieldsService.instance.revision.addListener(_onFieldsChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    FieldsService.instance.revision.removeListener(_onFieldsChanged);
    _scrollController.dispose();
    _stagger.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  /// قربنا من نهاية القائمة؟ نجيب الدفعة الجاية قبل ما يوصلها المستخدم
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 600) return;
    if (!FieldsService.instance.hasMore) return;
    FieldsService.instance.loadMore();
  }

  bool get _isBrowsing =>
      _searchController.text.trim().isEmpty &&
      _selectedSport == null &&
      _selectedCity == null;

  /// البحث والفلترة لازم يشوفون كل الملاعب — مو أول دفعة فقط.
  /// أول ما يفلتر المستخدم نكمّل تحميل الباقي بالخلفية.
  void _ensureFullCatalog() {
    if (!FieldsService.instance.hasMore) return;
    FieldsService.instance.loadAllFields();
  }

  @override
  Widget build(BuildContext context) {
    final fields = FieldsService.instance.search(
      query: _searchController.text,
      sport: _selectedSport,
      city: _selectedCity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          selectedCity: _selectedCity,
          searchController: _searchController,
          onCityChanged: (city) {
            _ensureFullCatalog();
            setState(() => _selectedCity = city);
          },
          onSearchChanged: () {
            _ensureFullCatalog();
            setState(() {});
          },
          onCityMenuOpened: _ensureFullCatalog,
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverList.list(
                children: [
              // بلاطات الرياضات — تمرير أفقي، الأنواع أكثر من عرض الشاشة
              Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      _SportTile(
                        label: AppStrings.allSports,
                        icon: Icons.apps_rounded,
                        selected: _selectedSport == null,
                        onTap: () => setState(() => _selectedSport = null),
                      ),
                      for (final sport in Sport.values)
                        _SportTile(
                          label: sport.label,
                          icon: sport.icon,
                          selected: _selectedSport == sport,
                          onTap: () => setState(() => _selectedSport = sport),
                        ),
                    ],
                  ),
                ),
              ),
              // بانر اللعبة — غامق بلمسة صفراء
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: _GameBanner(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    );
                  },
                ),
              ),
              // العب اليوم — يختفي أثناء البحث والفلترة
              if (!_loading && _isBrowsing) const PlayNowSection(),
              // العروض والإعلانات — يختفي كلياً لو ماكو إعلانات نشطة
              if (!_loading && _isBrowsing) const AdsSection(),
              // عنوان قائمة الملاعب
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 12),
                child: Row(
                  children: [
                    Text(
                      _isBrowsing
                          ? AppStrings.allFieldsTitle
                          : AppStrings.resultsTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                    const Spacer(),
                    if (!_loading)
                      Text(
                        '${fields.length} ${AppStrings.fieldWord}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
                  // حالات ما بيها بطاقات: تحميل أول دفعة، أو نتائج فارغة
                  if (_loading)
                    for (var i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(22, 0, 22, 16),
                        child: _FieldCardSkeleton(),
                      )
                  else if (fields.isEmpty)
                    _EmptyResults(
                      onClear: () {
                        _searchController.clear();
                        setState(() {
                          _selectedSport = null;
                          _selectedCity = null;
                        });
                      },
                    ),
                ],
              ),
              // الملاعب — تنبنى وحدة وحدة عند ظهورها فقط (تمرير خفيف)
              if (!_loading && fields.isNotEmpty)
                SliverList.builder(
                  itemCount: fields.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                    child: _staggered(i, FieldCard(field: fields[i])),
                  ),
                ),
              // ذيل القائمة: هيكل تحميل صغير إذا باقي دفعات بالطريق
              SliverToBoxAdapter(
                child: !_loading && _isBrowsing && FieldsService.instance.hasMore
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(22, 0, 22, 16),
                        child: _FieldCardSkeleton(),
                      )
                    : const SizedBox(height: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// دخول متتالي ناعم لأول البطاقات
  Widget _staggered(int i, Widget child) {
    final start = (i * 0.12).clamp(0.0, 0.55);
    final anim = CurvedAnimation(
      parent: _stagger,
      curve: Interval(
        start,
        (start + 0.45).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }
}

/// رأس الصفحة الأخضر — تحية + مدينة + خريطة + بحث
class _Header extends StatelessWidget {
  const _Header({
    required this.selectedCity,
    required this.searchController,
    required this.onCityChanged,
    required this.onSearchChanged,
    required this.onCityMenuOpened,
  });

  final String? selectedCity;
  final TextEditingController searchController;
  final ValueChanged<String?> onCityChanged;
  final VoidCallback onSearchChanged;

  /// فتح قائمة المدن — نكمّل تحميل الملاعب حتى تبين كل المدن
  final VoidCallback onCityMenuOpened;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // تحية شخصية
                        ValueListenableBuilder<int>(
                          valueListenable: UserService.instance.revision,
                          builder: (context, _, _) {
                            final name = UserService.instance.name;
                            return Text(
                              name.isEmpty
                                  ? AppStrings.homeHello
                                  : AppStrings.homeHelloNamed(name),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white
                                    .withValues(alpha: 0.85),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 3),
                        // اختيار المدينة
                        PopupMenuButton<String>(
                          onSelected: (value) => onCityChanged(
                            value == AppStrings.allIraq ? null : value,
                          ),
                          onOpened: onCityMenuOpened,
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 190,
                            maxHeight: 380,
                          ),
                          itemBuilder: (context) => [
                            for (final city in [
                              AppStrings.allIraq,
                              ...FieldsService.instance.cities,
                            ])
                              PopupMenuItem(
                                value: city,
                                height: 42,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        city,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if ((selectedCity ?? AppStrings.allIraq) ==
                                        city)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedCity ?? AppStrings.allIraq,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // زر الخريطة
                  Pressable(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FieldsMapScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.map_outlined,
                        color: AppColors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // خانة البحث
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF15803D).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, color: AppColors.muted, size: 21),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        // ما نسمح بأي رمز خطير (كود / SQL) بخانة البحث
                        inputFormatters: [InputSanitizer.deny()],
                        maxLength: 50,
                        onChanged: (_) => onSearchChanged(),
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark,
                        ),
                        decoration: InputDecoration(
                          hintText: AppStrings.searchHint,
                          hintStyle: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // "ما لگيت ملعبك؟ اقترحه" — رابط دائم تحت البحث حتى اللاعب
              // يعرف من البداية إنه يقدر يبلغ عن ملعب ناقص
              Center(
                child: Pressable(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SuggestVenueScreen(),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_location_alt_outlined,
                        size: 15,
                        color: AppColors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppStrings.suggestVenueCta,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white.withValues(alpha: 0.9),
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بلاطة رياضة — مربع مستدير 62px مع التسمية تحته
class _SportTile extends StatelessWidget {
  const _SportTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 70,
        margin: const EdgeInsetsDirectional.only(end: 12),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.30),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 29,
              color: selected ? AppColors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          // الأسماء الطويلة (نادي رياضي) تصغّر بدل ما تنقص أو تفيض
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.dark : AppColors.grey,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// بانر اللعبة — تدرج غامق مع توهج أصفر
class _GameBanner extends StatelessWidget {
  const _GameBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        // 112 هو ارتفاع التصميم — نخليه حد أدنى حتى ما يفيض النص مع خط Cairo
        constraints: const BoxConstraints(minHeight: 112),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // توهج أصفر خلف المحتوى
            PositionedDirectional(
              end: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.gameEyebrow,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    AppStrings.gameHeadline,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      AppStrings.gameCta,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkFixed,
                      ),
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

/// حالة فارغة للبحث
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppStrings.noResults,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.grey,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onClear,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 22),
            ),
            child: const Text(AppStrings.clearFilters),
          ),
          const SizedBox(height: 14),
          // ما لگى نتائج؟ نعرضله فرصة يقترح الملعب اللي يدوّر عليه
          Pressable(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SuggestVenueScreen()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_location_alt_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  AppStrings.suggestVenueCta,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
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

/// هيكل تحميل بطاقة ملعب
class _FieldCardSkeleton extends StatelessWidget {
  const _FieldCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final shimmer = AppColors.subtleFill;

    Widget block(double width, double height, [double radius = 8]) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: shimmer,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

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
          block(double.infinity, 128, 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(150, 18),
                const SizedBox(height: 8),
                block(210, 13),
                const SizedBox(height: 14),
                Row(
                  children: [
                    block(110, 16),
                    const Spacer(),
                    block(38, 38, 19),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
