import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/navigation/owner_tabs.dart';
import '../../../core/services/app_mode.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/screens/login_screen.dart';
import 'owner_ads_screen.dart';
import 'owner_bookings_screen.dart';
import 'owner_dashboard_screen.dart';
import 'owner_settings_screen.dart';
import 'owner_venues_screen.dart';

/// الهيكل الرئيسي لحساب صاحب المنشأة — حساب منفصل بالكامل عن حساب
/// اللاعب، بخمس تبويبات: لوحة التحكم، الحجوزات، منشآتي، إعلاناتي،
/// والإعدادات.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  /// منشآت صاحب الحساب — null لين ما تتحمّل أول مرة
  List<Field>? _fields;

  /// نفس حارس الجلسة المستخدم بحساب اللاعب — يطرد المستخدم لشاشة
  /// الدخول فوراً لو انتهت جلسة Firebase (خروج / حذف حساب)
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadFields();
    if (Firebase.apps.isNotEmpty) {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null || !mounted) return;
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

  Future<void> _loadFields() async {
    final uid = AppMode.isMock
        ? 'mock-user'
        : FirebaseAuth.instance.currentUser?.uid ?? '';
    final fields = await FieldsService.instance.myFields(uid);
    if (mounted) setState(() => _fields = fields);
  }

  @override
  Widget build(BuildContext context) {
    // نسمع متحكّم الوضع الليلي هنا أيضاً — IndexedStack يبقي كل
    // التبويبات مبنية بالذاكرة حتى وهي مخفية، فتبديل الثيم من أي
    // تبويب لازم يعيد بناءها هنا حتى تلتقط الألوان الجديدة فوراً.
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance.isDark,
      builder: (context, _, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final fields = _fields;
    if (fields == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: OwnerTabs.current,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            OwnerDashboardScreen(
              // مفتاح مرتبط بعدد المنشآت — لو انضافت وحدة جديدة، اللوحة
              // تعيد بناء نفسها من جذرها حتى تلتقطها (بعكس التعديل
              // بمنشأة موجودة، اللي يشتغل عبر onFieldChanged الطبيعي)
              key: ValueKey('owner-dashboard-${fields.length}'),
              fields: fields,
              showBackButton: false,
            ),
            OwnerBookingsScreen(fields: fields),
            OwnerVenuesScreen(fields: fields, onChanged: _loadFields),
            OwnerAdsScreen(fields: fields),
            OwnerSettingsScreen(
              fields: fields,
              onFieldsChanged: _loadFields,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: OwnerTabs.go,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: AppStrings.ownerShellDashboard,
            ),
            NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available_rounded),
              label: AppStrings.ownerShellBookings,
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: AppStrings.ownerShellVenues,
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign_rounded),
              label: AppStrings.myAdsTitle,
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: AppStrings.settingsTitle,
            ),
          ],
        ),
      ),
    );
  }
}
