import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/admin_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/navigation/app_tabs.dart';
import '../../core/services/app_mode.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_store.dart';
import '../../core/services/bookings_service.dart';
import '../../core/services/reviews_service.dart';
import '../../core/services/user_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/arabic_num.dart';
import '../../core/widgets/pressable.dart';
import '../admin/screens/admin_venue_suggestions_screen.dart';
import '../auth/screens/login_screen.dart';
import '../bookings/screens/bookings_tab.dart';
import '../home/screens/home_screen.dart';
import '../players/screens/players_tab.dart';
import '../profile/screens/favorites_screen.dart';
import '../profile/screens/leaderboard_screen.dart';
import '../profile/screens/my_reviews_screen.dart';
import '../profile/screens/player_profile_screen.dart';
import '../profile/screens/settings_screen.dart';
import '../splash/splash_screen.dart';
import '../venues/screens/my_venue_suggestions_screen.dart';

/// رقم واتساب الدعم — نفس رقم شاشة الإعدادات
const String _supportPhone = '+9647701234567';

/// الهيكل الرئيسي — تبويبات سفلية: الرئيسية، حجوزاتي، ناقصنا لاعب، حسابي
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// حارس الجلسة: إذا انتهت جلسة Firebase (انتهاء توكن / حذف حساب /
  /// تسجيل خروج) نرجّع المستخدم لشاشة الدخول فوراً.
  /// وبنفس الوقت يمنع الواصل غير المسجّل من البقاء بأي شاشة داخلية.
  StreamSubscription<User?>? _authSub;

  /// آخر وقت ضغط المستخدم زر الرجوع وهو بأحد التبويبات الرئيسية —
  /// يمنع الخروج المفاجئ من التطبيق بضغطة وحدة
  DateTime? _lastBackPressAt;

  void _handleRootBackPress() {
    final now = DateTime.now();
    if (_lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.pressBackAgainToExit),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (Firebase.apps.isNotEmpty) {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null || !mounted) return;
        // الجلسة المحلية (الدخول التجريبي) ما تنكسر بغياب مستخدم Firebase —
        // نطرد فقط إذا حتى الجلسة المحلية ممسوحة (خروج فعلي / حذف حساب)
        if (await LocalStore.signedIn) return;
        if (!mounted) return;
        UserService.instance.resetForSignOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // نسمع متحكّم الوضع الليلي هنا أيضاً — IndexedStack يبقي كل
    // التبويبات الأربعة مبنية بالذاكرة حتى وهي مخفية (يشمل تبويب
    // "حسابي" وشاشة الإعدادات المفتوحة فوقه)، فتبديل الثيم من أي
    // مكان لازم يعيد بناءها هنا حتى تلتقط الألوان الجديدة فوراً —
    // بدل إعادة بناء التطبيق كامل من جذره وفقدان كومة التنقل.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleRootBackPress();
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: ThemeController.instance.isDark,
        builder: (context, _, _) => _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    // نسمع متحكّم التبويبات حتى أي شاشة تگدر تنقل المستخدم (زر تصفّح الملاعب...)
    return ValueListenableBuilder<int>(
      valueListenable: AppTabs.current,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(
          index: index,
          children: const [
            HomeTab(),
            BookingsTab(),
            PlayersTab(),
            _ProfileTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: AppTabs.go,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available_rounded),
              label: 'حجوزاتي',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_add_outlined),
              selectedIcon: Icon(Icons.group_add_rounded),
              label: 'ناقصنا لاعب',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}

/// تبويب حسابي
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  @override
  void initState() {
    super.initState();
    _loadCounts();
    // نستمع تحديثات الحجوزات والتقييمات حتى الأرقام تتحدث لحظياً بدل
    // ما تضل ثابتة إلى ما يعاد بناء التبويب (IndexedStack يحافظ عليه حي)
    BookingsService.instance.revision.addListener(_loadCounts);
    ReviewsService.instance.revision.addListener(_loadCounts);
  }

  @override
  void dispose() {
    BookingsService.instance.revision.removeListener(_loadCounts);
    ReviewsService.instance.revision.removeListener(_loadCounts);
    super.dispose();
  }

  String get _phone {
    if (AppMode.isMock) return 'ضيف';
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber ?? 'ضيف';
  }

  /// أعداد البطاقات الثلاث (حجوزات / مفضلة / تقييمات)
  int _bookingsCount = 0;
  int _reviewsCount = 0;

  Future<void> _loadCounts() async {
    try {
      final bookings = await BookingsService.instance.myBookings();
      final reviews = await ReviewsService.instance.myReviews();
      if (mounted) {
        setState(() {
          _bookingsCount = bookings.length;
          _reviewsCount = reviews.length;
        });
      }
    } catch (_) {
      // ما نكسر الشاشة إذا فشل التحميل — الأعداد تبقى صفر
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // رأس أخضر: أفاتار + اسم + رقم
          Container(
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
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 60),
                child: ValueListenableBuilder<int>(
                  valueListenable: UserService.instance.revision,
                  builder: (context, _, _) {
                    final name = UserService.instance.name;
                    final photoUrl = UserService.instance.photoUrl;
                    final initial = name.isEmpty ? '؟' : name.characters.first;
                    return Column(
                      children: [
                        Pressable(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerProfileScreen(
                                uid: UserService.instance.uid,
                                isOwn: true,
                              ),
                            ),
                          ),
                          child: Container(
                            width: 88,
                            height: 88,
                            alignment: Alignment.center,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 26,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: photoUrl.isEmpty
                                ? Text(
                                    initial,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    fit: BoxFit.cover,
                                    width: 88,
                                    height: 88,
                                    errorWidget: (_, _, _) => Text(
                                      initial,
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name.isEmpty ? AppStrings.guestName : name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _phone,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // بطاقات الأرقام — تطلع فوق الرأس الأخضر
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ValueListenableBuilder<int>(
                    valueListenable: UserService.instance.revision,
                    builder: (context, _, _) => Row(
                      children: [
                        _StatCard(
                          value: ArabicNum.count(_bookingsCount),
                          label: AppStrings.bookingWord,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: ArabicNum.count(
                            UserService.instance.favoriteIds.length,
                          ),
                          label: AppStrings.favoritesWord,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          value: ArabicNum.count(_reviewsCount),
                          label: AppStrings.reviewsWord,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // قائمة الحساب
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      _ProfileItem(
                        icon: Icons.emoji_events_rounded,
                        label: AppStrings.myProfileItem,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerProfileScreen(
                                uid: UserService.instance.uid,
                                isOwn: true,
                              ),
                            ),
                          );
                        },
                      ),
                      _ProfileItem(
                        icon: Icons.leaderboard_rounded,
                        label: AppStrings.leaderboardItem,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),
                      _ProfileItem(
                        icon: Icons.favorite_rounded,
                        label: 'المفضلة',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FavoritesScreen(),
                            ),
                          );
                        },
                      ),
                      _ProfileItem(
                        icon: Icons.star_rounded,
                        label: 'تقييماتي',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyReviewsScreen(),
                            ),
                          );
                        },
                      ),
                      _ProfileItem(
                        icon: Icons.stadium_rounded,
                        label: AppStrings.mySuggestionsItem,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyVenueSuggestionsScreen(),
                            ),
                          );
                        },
                      ),
                      // لوحة إدارة اقتراحات الملاعب — تظهر فقط لحساب
                      // المسؤول (قائمة adminUids بملف admin_config.dart)
                      if (AdminConfig.isCurrentUserAdmin)
                        _ProfileItem(
                          icon: Icons.admin_panel_settings_rounded,
                          label: AppStrings.adminSuggestionsItem,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AdminVenueSuggestionsScreen(),
                              ),
                            );
                          },
                        ),
                      // مفتاح الوضع الليلي
                      _ProfileItem(
                        icon: ThemeController.instance.isDark.value
                            ? Icons.dark_mode_rounded
                            : Icons.dark_mode_outlined,
                        label: 'الوضع الليلي',
                        trailing: Switch(
                          value: ThemeController.instance.isDark.value,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) =>
                              UserService.instance.saveThemeDark(v),
                        ),
                      ),
                      _ProfileItem(
                        icon: Icons.settings_rounded,
                        label: 'الإعدادات',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _ProfileItem(
                        icon: Icons.headset_mic_rounded,
                        label: 'تواصل ويانا',
                        last: true,
                        onTap: _contactSupport,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // تسجيل الخروج ببطاقة منفصلة
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: _ProfileItem(
                    icon: Icons.logout_rounded,
                    label: AppStrings.logout,
                    danger: true,
                    last: true,
                    onTap: () async {
                      await AuthService.instance.signOut();
                      // مع Firebase: حارس الجلسة بالأعلى يلتقط الخروج
                      // ويوجّه لشاشة الدخول — ما ننقل مرتين
                      if (Firebase.apps.isNotEmpty) return;
                      UserService.instance.resetForSignOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
                        (route) => false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSupport() async {
    final phone = _supportPhone.replaceAll('+', '');
    await launchUrl(
      Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(AppStrings.supportWhatsappMessage)}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// بطاقة رقم بالملف الشخصي (حجز / مفضلة / تقييم)
class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
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

/// عنصر بقائمة الحساب — مربّع أيقونة + عنوان + سهم/شارة/مفتاح
class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// عنصر بمفتاح بدل السهم (الوضع الليلي)
  final Widget? trailing;

  /// أحمر (تسجيل الخروج)
  final bool danger;

  /// آخر عنصر بالبطاقة — بدون خط سفلي
  final bool last;

  @override
  Widget build(BuildContext context) {
    final Color tileColor = danger ? AppColors.errorSoft : AppColors.primaryTint;
    final Color iconColor = danger ? AppColors.error : AppColors.primary;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: last
              ? null
              : BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.hairline)),
                ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: danger ? AppColors.error : AppColors.dark,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else if (!danger)
                Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.border,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
