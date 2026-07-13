import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/field.dart';
import '../../../core/services/fields_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/field_image.dart';
import '../../../core/widgets/pressable.dart';
import '../../fields/screens/field_details_screen.dart';

/// خريطة الملاعب — دبابيس تفاعلية لكل ملعب مع بطاقة تفاصيل سريعة.
///
/// طبقة البلاطات حالياً OpenStreetMap (مجانية بدون مفتاح).
/// عند تفعيل فوترة Google Maps مستقبلاً يكفي تبديل [_tileUrl]
/// (المفتاح جاهز: Shoot Maps Key بمشروع shoot-iraq).
class FieldsMapScreen extends StatefulWidget {
  const FieldsMapScreen({super.key});

  @override
  State<FieldsMapScreen> createState() => _FieldsMapScreenState();
}

class _FieldsMapScreenState extends State<FieldsMapScreen> {
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// نظرة عامة على العراق كله
  static const LatLng _iraqCenter = LatLng(33.2232, 43.6793);
  static const double _iraqZoom = 6.2;

  final MapController _mapController = MapController();
  List<Field> _fields = const [];

  /// مركز كل مدينة = معدّل إحداثيات ملاعبها (يتولد من البيانات)
  Map<String, LatLng> _cityCenters = const {};
  Field? _selected;

  /// null = عرض العراق كله
  String? _city;

  @override
  void initState() {
    super.initState();
    FieldsService.instance.loadFields().then((all) {
      if (!mounted) return;
      final fields = all.where((f) => f.hasLocation).toList();

      // نجمع الملاعب حسب المدينة ونحسب مركز كل مدينة
      final grouped = <String, List<Field>>{};
      for (final f in fields) {
        (grouped[f.city] ??= []).add(f);
      }
      final centers = {
        for (final entry in grouped.entries)
          entry.key: LatLng(
            entry.value.map((f) => f.lat).reduce((a, b) => a + b) /
                entry.value.length,
            entry.value.map((f) => f.lng).reduce((a, b) => a + b) /
                entry.value.length,
          ),
      };
      // المدن الأكثر ملاعب أولاً
      final sortedCities = grouped.keys.toList()
        ..sort((a, b) => grouped[b]!.length.compareTo(grouped[a]!.length));

      setState(() {
        _fields = fields;
        _cityCenters = {
          for (final c in sortedCities) c: centers[c]!,
        };
      });
    });
  }

  /// عدد ملاعب مدينة معيّنة
  int _countIn(String city) =>
      _fields.where((f) => f.city == city).length;

  void _jumpToCity(String? city) {
    setState(() {
      _city = city;
      _selected = null;
    });
    if (city == null) {
      _mapController.move(_iraqCenter, _iraqZoom);
      return;
    }
    final center = _cityCenters[city];
    if (center != null) _mapController.move(center, 12);
  }

  void _openDirections(Field field) {
    launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${field.lat},${field.lng}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _fields.isEmpty
              ? AppStrings.mapTitle
              : '${AppStrings.mapTitle} (${_fields.length})',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _iraqCenter,
              initialZoom: _iraqZoom,
              minZoom: 5,
              maxZoom: 18,
              // نلغي تحديد الملعب عند الضغط على الخريطة
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.shootapp.shoot',
                // بدون نت: نكمل بخلفية فارغة بدل ما نكسر الشاشة
                errorTileCallback: (_, _, _) {},
              ),
              MarkerLayer(
                markers: [
                  for (final field in _fields)
                    Marker(
                      point: LatLng(field.lat, field.lng),
                      width: 46,
                      height: 54,
                      child: _FieldPin(
                        field: field,
                        selected: field.id == selected?.id,
                        onTap: () => setState(() => _selected = field),
                      ),
                    ),
                ],
              ),
              // حقوق OpenStreetMap (مطلوبة)
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
          // شريط المدن — يتولد من الملاعب الموجودة، الأكثر ملاعب أولاً
          PositionedDirectional(
            top: 10,
            start: 0,
            end: 0,
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _CityChip(
                    label: AppStrings.allIraq,
                    count: _fields.length,
                    selected: _city == null,
                    onTap: () => _jumpToCity(null),
                  ),
                  for (final city in _cityCenters.keys)
                    _CityChip(
                      label: city,
                      count: _countIn(city),
                      selected: _city == city,
                      onTap: () => _jumpToCity(city),
                    ),
                ],
              ),
            ),
          ),
          // بطاقة الملعب المختار
          if (selected != null)
            PositionedDirectional(
              bottom: 16,
              start: 16,
              end: 16,
              child: _SelectedFieldCard(
                field: selected,
                onDirections: () => _openDirections(selected),
                onClose: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }
}

/// شيب مدينة بشريط الخريطة — الاسم وعدد ملاعبها
class _CityChip extends StatelessWidget {
  const _CityChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected ? AppColors.white : AppColors.dark,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$count',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: selected ? AppColors.white : AppColors.primaryDeep,
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

/// دبوس ملعب على الخريطة — دائرة خضراء بأيقونة الرياضة وذيل صغير
class _FieldPin extends StatelessWidget {
  const _FieldPin({
    required this.field,
    required this.selected,
    required this.onTap,
  });

  final Field field;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('pin-${field.id}'),
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: selected ? 44 : 38,
            height: selected ? 44 : 38,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFFFACC15) : Colors.white,
                width: selected ? 3 : 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              field.sport.icon,
              size: selected ? 24 : 20,
              color: Colors.white,
            ),
          ),
          // ذيل الدبوس
          CustomPaint(
            size: const Size(10, 8),
            painter: _PinTailPainter(),
          ),
        ],
      ),
    );
  }
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF0B5D2B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// بطاقة سريعة للملعب المختار أسفل الخريطة
class _SelectedFieldCard extends StatelessWidget {
  const _SelectedFieldCard({
    required this.field,
    required this.onDirections,
    required this.onClose,
  });

  final Field field;
  final VoidCallback onDirections;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat('#,###').format(field.pricePerHour);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 62,
                    height: 52,
                    child: FieldImage(field: field),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: AppColors.star,
                          ),
                          Text(
                            ' ${field.rating}  •  ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            '$price ${AppStrings.iqd} ${AppStrings.perHour}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Pressable(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FieldDetailsScreen(field: field),
                          ),
                        );
                      },
                      child: const Text(
                        AppStrings.viewAndBook,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Pressable(
                    child: OutlinedButton.icon(
                      onPressed: onDirections,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: BorderSide(color: AppColors.border),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: AppTheme.cairo(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      icon: const Icon(Icons.directions_rounded, size: 19),
                      label: const Text(AppStrings.directionsLabel),
                    ),
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
