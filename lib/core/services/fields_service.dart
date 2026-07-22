import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/field.dart';
import '../utils/image_validation.dart';
import '../utils/input_sanitizer.dart';
import 'app_mode.dart';
import 'supabase_storage_service.dart';

export '../utils/image_validation.dart' show InvalidImageException;

/// خدمة الملاعب — تقرأ من Firestore، ومع أي خلل (لا نت / لا Firebase)
/// ترجع للبيانات التجريبية حتى يبقى التطبيق شغال.
class FieldsService {
  FieldsService._();

  static final FieldsService instance = FieldsService._();

  /// عدد الملاعب بالدفعة الوحدة — أول دفعة تكفي ملء الشاشة وزيادة
  static const int defaultPageSize = 15;

  /// حجم دفعة مصغّر للاختبارات فقط (البيانات التجريبية أقل من الدفعة الكاملة)
  @visibleForTesting
  static int? debugPageSize;

  static int get pageSize => debugPageSize ?? defaultPageSize;

  /// تصفير كامل — للاختبارات حتى كل اختبار يبدي من نقطة معروفة
  @visibleForTesting
  void debugReset() {
    _cache = null;
    _cursor = null;
    _mockLoaded = 0;
    _hasMore = true;
    _pendingPage = null;
  }

  /// كم ملعب تجريبي تحمّل لحد الآن (وضع التجربة يقلّد الدفعات)
  int _mockLoaded = 0;

  /// آخر قائمة محمّلة — البحث والفلترة يشتغلون عليها فورياً
  List<Field>? _cache;

  /// مؤشر آخر مستند وصلنا له — منه تبدي الدفعة الجاية
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  /// باقي بالسيرفر ملاعب ما تحمّلت؟
  bool _hasMore = true;

  /// هل بعد بيه ملاعب تنتظر التحميل؟ (الرئيسية تستخدمه لمؤشر التمرير)
  bool get hasMore => _hasMore;

  /// يزيد مع كل دفعة جديدة توصل — الشاشات تسمعه وتحدّث نفسها
  final ValueNotifier<int> revision = ValueNotifier(0);

  /// جلب جاري — أي نداء ثاني بنفس اللحظة ينتظر نفس الدفعة
  /// بدل ما يطلبها مرتين من الشبكة
  Future<List<Field>>? _pendingPage;

  /// أول دفعة من الملاعب — تخلي الشاشة تظهر بسرعة.
  /// الباقي يجي مع التمرير ([loadMore]) أو عند أي عملية
  /// تحتاج القائمة كاملة ([loadAllFields]).
  Future<List<Field>> loadFields() async {
    final cached = _cache;
    if (cached != null) return cached;
    return _fetchNextPage();
  }

  /// الدفعة الجاية — يناديها التمرير لأسفل بالرئيسية
  Future<List<Field>> loadMore() async {
    if (!_hasMore) return _cache ?? const [];
    return _fetchNextPage();
  }

  /// القائمة كاملة — تكمّل كل الدفعات الباقية.
  ///
  /// ضرورية لأي شي يشتغل على كل الملاعب: الخريطة، البحث والفلترة،
  /// قائمة المدن، وملاعب المالك — حتى ما تضيع ملاعب ما وصلت بعد.
  Future<List<Field>> loadAllFields() async {
    var list = await loadFields();
    while (_hasMore) {
      list = await _fetchNextPage();
    }
    return list;
  }

  Future<List<Field>> _fetchNextPage() {
    final pending = _pendingPage;
    if (pending != null) return pending;
    final future = _fetchPage().whenComplete(() => _pendingPage = null);
    _pendingPage = future;
    return future;
  }

  Future<List<Field>> _fetchPage() async {
    // وضع التجربة: نفس منطق الدفعات بس على البيانات التجريبية
    // (نسخة قابلة للتعديل حتى تعديلات المالك تشتغل بالذاكرة)
    if (AppMode.isMock) {
      final list = _cache ??= <Field>[];
      final next = _mockFields.skip(_mockLoaded).take(pageSize).toList();
      _mockLoaded += next.length;
      list.addAll(next);
      _hasMore = _mockLoaded < _mockFields.length;
      if (next.isNotEmpty) revision.value++;
      return list;
    }

    try {
      // الترتيب بالسيرفر ضروري حتى يشتغل مؤشر الدفعات (startAfterDocument)
      var query = FirebaseFirestore.instance
          .collection('fields')
          .where('isActive', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(pageSize);
      final cursor = _cursor;
      if (cursor != null) query = query.startAfterDocument(cursor);

      final snapshot = await query.get().timeout(const Duration(seconds: 10));
      final docs = snapshot.docs;
      if (docs.isNotEmpty) _cursor = docs.last;
      // دفعة ناقصة = وصلنا للنهاية
      _hasMore = docs.length == pageSize;

      final list = _cache ??= <Field>[];
      list.addAll([for (final doc in docs) Field.fromMap(doc.id, doc.data())]);

      // ولا ملعب وصل أبداً؟ نرجع للبيانات التجريبية بدل شاشة فارغة
      if (list.isEmpty) {
        _hasMore = false;
        return _cache = List.of(_mockFields);
      }

      revision.value++;
      return list;
    } catch (_) {
      // بدون نت أو أي خطأ: نوقف الدفعات، ونرجع اللي وصل
      // (أو البيانات التجريبية إذا ما وصل ولا شي)
      _hasMore = false;
      return _cache ??= List.of(_mockFields);
    }
  }

  static const List<Field> _mockFields = [
    Field(
      id: 'f1',
      lat: 33.3033,
      lng: 44.3399,
      name: 'ملعب النجوم',
      area: 'المنصور',
      city: 'بغداد',
      sport: Sport.football,
      pricePerHour: 25000,
      rating: 4.8,
      reviewsCount: 124,
      // بوضع الاختبار: المستخدم التجريبي صاحب هذا الملعب
      ownerId: 'mock-user',
      description:
          'ملعب خماسي بعشب صناعي جيل جديد، إضاءة LED قوية تخلي اللعب الليلي متعة. من أشهر ملاعب المنصور وأكثرها حجزاً.',
      amenities: [
        Amenity.parking,
        Amenity.lights,
        Amenity.water,
        Amenity.changing,
      ],
    ),
    Field(
      id: 'f2',
      lat: 33.3324,
      lng: 44.4406,
      name: 'ملعب الأبطال',
      area: 'زيونة',
      city: 'بغداد',
      sport: Sport.football,
      pricePerHour: 30000,
      rating: 4.6,
      reviewsCount: 89,
    ),
    Field(
      id: 'f3',
      lat: 33.2795,
      lng: 44.3787,
      name: 'بادل هاوس',
      area: 'الجادرية',
      city: 'بغداد',
      sport: Sport.padel,
      pricePerHour: 40000,
      rating: 4.9,
      reviewsCount: 203,
    ),
    Field(
      id: 'f4',
      lat: 33.3067,
      lng: 44.4225,
      name: 'ملعب الرافدين',
      area: 'الكرادة',
      city: 'بغداد',
      sport: Sport.football,
      pricePerHour: 20000,
      rating: 4.3,
      reviewsCount: 57,
    ),
    Field(
      id: 'f5',
      lat: 33.2966,
      lng: 44.3357,
      name: 'سلة العراق',
      area: 'المنصور',
      city: 'بغداد',
      sport: Sport.basketball,
      pricePerHour: 15000,
      rating: 4.5,
      reviewsCount: 41,
    ),
    Field(
      id: 'f6',
      lat: 33.2731,
      lng: 44.3852,
      name: 'تنس بغداد كلوب',
      area: 'الجادرية',
      city: 'بغداد',
      sport: Sport.tennis,
      pricePerHour: 35000,
      rating: 4.7,
      reviewsCount: 66,
    ),
    Field(
      id: 'f7',
      lat: 30.5233,
      lng: 47.8253,
      name: 'ملعب شط العرب',
      area: 'العشار',
      city: 'البصرة',
      sport: Sport.football,
      pricePerHour: 20000,
      rating: 4.4,
      reviewsCount: 73,
    ),
    Field(
      id: 'f8',
      lat: 36.2266,
      lng: 43.9946,
      name: 'بادل أربيل',
      area: 'عنكاوا',
      city: 'أربيل',
      sport: Sport.padel,
      pricePerHour: 45000,
      rating: 4.8,
      reviewsCount: 150,
    ),
    // منشآت الفئات الجديدة: مسبح (حجز بالساعة) ومركز علاج (حجز بالجلسة)
    Field(
      id: 'f9',
      lat: 33.3719,
      lng: 44.3611,
      name: 'مسبح بغداد الأولمبي',
      area: 'الأعظمية',
      city: 'بغداد',
      sport: Sport.swimming,
      pricePerHour: 10000,
      rating: 4.6,
      reviewsCount: 88,
      openHour: 8,
      closeHour: 22,
      description:
          'مسبح أولمبي مدفّأ بمسارات سباحة نظامية، مدربين متوفرين ويوجد وقت خاص للعوائل. المي تتبدل وتتعقم يومياً.',
      amenities: [Amenity.parking, Amenity.changing, Amenity.water],
    ),
    Field(
      id: 'f10',
      lat: 33.3128,
      lng: 44.3615,
      name: 'مركز الشفاء للعلاج الرياضي',
      area: 'الحارثية',
      city: 'بغداد',
      sport: Sport.therapy,
      pricePerHour: 25000,
      rating: 4.7,
      reviewsCount: 64,
      openHour: 9,
      closeHour: 21,
      // بوضع الاختبار: المستخدم التجريبي صاحب هذا المركز (إضافة لملعبه)
      ownerId: 'mock-user',
      description:
          'مركز متخصص بالعلاج الرياضي والطبيعي — تأهيل إصابات الملاعب، جلسات مساج علاجي، ومتابعة مع أخصائيين مجازين.',
      amenities: [Amenity.parking, Amenity.wifi],
      services: [
        VenueService(name: 'تأهيل إصابات رياضية', price: 30000),
        VenueService(name: 'جلسة علاج طبيعي', price: 25000),
        VenueService(name: 'مساج رياضي', price: 20000),
      ],
    ),
  ];

  /// ملاعب المستخدم الحالي (إذا هو صاحب ملعب) — فارغة للاعب العادي.
  /// تحتاج القائمة كاملة حتى ما يضيع ملعب المالك بدفعة ما تحمّلت.
  Future<List<Field>> myFields(String userId) async {
    if (userId.isEmpty) return const [];
    final fields = await loadAllFields();
    return fields.where((f) => f.ownerId == userId).toList();
  }

  /// المدن المتوفرة (من الملاعب المحمّلة) — للفلترة
  List<String> get cities {
    final seen = <String>{};
    return [
      for (final f in _cache ?? _mockFields)
        if (seen.add(f.city)) f.city,
    ];
  }

  /// بحث وفلترة على آخر قائمة محمّلة (فوري، بدون انتظار الشبكة)
  /// نص البحث ينظّف من أي رموز خطيرة قبل ما يُستخدم
  List<Field> search({String query = '', Sport? sport, String? city}) {
    final q = InputSanitizer.clean(query, maxLength: 50);
    return (_cache ?? _mockFields).where((f) {
      final matchesSport = sport == null || f.sport == sport;
      final matchesCity = city == null || f.city == city;
      final matchesQuery =
          q.isEmpty ||
          f.name.contains(q) ||
          f.area.contains(q) ||
          f.city.contains(q);
      return matchesSport && matchesCity && matchesQuery;
    }).toList();
  }

  /// ملعب بمعرّفه من آخر قائمة محمّلة — null إذا ما موجود
  Field? byId(String id) {
    for (final f in _cache ?? _mockFields) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// قيمة العربون الثابتة (دينار عراقي) — تنسحب من الإعدادات لاحقاً
  static const int depositAmount = 5000;

  /// هل رفع الصور متاح؟ يحتاج Firebase مفعّل (مو وضع التجربة المحلي)
  static bool get canUploadPhotos => !AppMode.isMock;

  /// فحص الملكية: ما نسمح بأي تعديل على ملعب مو تابع للمستخدم الحالي.
  /// (قواعد Firestore تمنع كتابة المستند من السيرفر — وهذا خط دفاع بالتطبيق)
  /// بوضع التجربة (بدون Firebase) المستخدم هو 'mock-user'.
  void _assertOwner(Field field) {
    final uid = AppMode.isMock
        ? 'mock-user'
        : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || field.ownerId != uid) {
      throw StateError('غير مخوّل: هذا الملعب مو تابع لحسابك');
    }
  }

  /// يكتب تعديلات المالك على مستند الملعب (دمج) ويحدّث الذاكرة.
  /// بوضع التجربة: التحديث بالذاكرة فقط حتى تبقى الواجهة شغالة.
  Future<Field> _saveOwnerUpdate(
    Field field,
    Map<String, Object?> data,
    Field updated,
  ) async {
    _assertOwner(field);
    if (!AppMode.isMock) {
      await FirebaseFirestore.instance
          .collection('fields')
          .doc(field.id)
          .set(data, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));
    }
    _replaceInCache(updated);
    return updated;
  }

  /// يبدّل الملعب بالذاكرة بنسخة محدّثة حتى تنعكس الصور بكل الشاشات فوراً
  void _replaceInCache(Field updated) {
    final list = _cache;
    if (list == null) return;
    final i = list.indexWhere((f) => f.id == updated.id);
    if (i != -1) list[i] = updated;
  }

  /// الحد الأقصى لحجم الصورة الواحدة: ٥ ميغابايت (من [ImageValidation])
  static const int maxPhotoBytes = ImageValidation.maxBytes;

  /// يتحقق من الملفات كلها (نفس تحقق [ImageValidation] المستخدم بكل نقاط
  /// الرفع بالتطبيق) ثم يرفعها لـ bucket بـ Supabase Storage ويرجّع
  /// روابطها العامة. يا كل الملفات تنرفع يا ولا واحد (التحقق قبل أول رفع).
  Future<List<String>> _uploadImages(
    Field field,
    String bucket,
    List<XFile> files,
  ) async {
    if (!canUploadPhotos) {
      throw StateError('رفع الصور يحتاج التطبيق المنشور (مو وضع التجربة)');
    }
    _assertOwner(field);

    final validated = [
      for (final file in files) await ImageValidation.validate(file),
    ];

    final newUrls = <String>[];
    for (final (ext, contentType, bytes) in validated) {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      newUrls.add(
        await SupabaseStorageService.upload(
          bucket: bucket,
          path: '${field.id}/$stamp.$ext',
          bytes: bytes,
          contentType: contentType,
        ),
      );
    }
    return newUrls;
  }

  /// حذف ملف من Supabase Storage برابطه — لو فشل (رابط قديم من Firebase
  /// أو Unsplash مثلاً) ما نكسر العملية
  Future<void> _deleteStorageFile(String url) async {
    try {
      await SupabaseStorageService.deleteByUrl(url);
    } catch (_) {}
  }

  /// يرفع صوراً جديدة للملعب على Supabase Storage ويحفظ روابطها بـ Firestore.
  /// يرجّع الملعب بنسخته المحدّثة (بكل الصور). يرمي استثناء عند الفشل.
  Future<Field> addFieldPhotos(Field field, List<XFile> files) async {
    if (files.isEmpty) return field;
    final newUrls = await _uploadImages(field, 'field-photos', files);
    final updatedUrls = [...field.imageUrls, ...newUrls];
    return _saveOwnerUpdate(field, {
      'imageUrls': updatedUrls,
    }, field.copyWith(imageUrls: updatedUrls));
  }

  /// يحذف صورة من الملعب — من Firestore ومن Storage.
  /// يرجّع الملعب بنسخته المحدّثة. يرمي استثناء عند الفشل.
  Future<Field> removeFieldPhoto(Field field, String url) async {
    if (!canUploadPhotos) {
      throw StateError('حذف الصور يحتاج التطبيق المنشور (مو وضع التجربة)');
    }
    final updatedUrls = [
      for (final u in field.imageUrls)
        if (u != url) u,
    ];
    final updated = await _saveOwnerUpdate(field, {
      'imageUrls': updatedUrls,
    }, field.copyWith(imageUrls: updatedUrls));
    await _deleteStorageFile(url);
    return updated;
  }

  /// إعادة ترتيب صور الملعب (أول صورة = الغلاف).
  /// الترتيب الجديد لازم يكون نفس الصور بدون زيادة أو نقصان.
  Future<Field> reorderFieldPhotos(Field field, List<String> ordered) async {
    if (ordered.length != field.imageUrls.length ||
        !ordered.toSet().containsAll(field.imageUrls)) {
      throw ArgumentError('ترتيب الصور الجديد لازم يضم نفس الصور');
    }
    return _saveOwnerUpdate(field, {
      'imageUrls': ordered,
    }, field.copyWith(imageUrls: ordered));
  }

  // ---------- التحقق من الروابط (نفس تحقق ImageValidation بكل النقاط) ----------

  /// رابط آمن؟ https فقط، بدون فراغات أو رموز خطيرة، وطول معقول
  static bool isValidHttpsUrl(String url) =>
      ImageValidation.isValidHttpsUrl(url);

  /// رابط فيديو مقبول للهايلايتس؟ https + يوتيوب أو انستغرام فقط
  static bool isValidVideoUrl(String url) =>
      ImageValidation.isValidVideoUrl(url);

  // ---------- المعلومات الأساسية ----------

  /// تحديث معلومات الملعب الأساسية — النصوص تنظّف بالـ sanitizer،
  /// والسعر والساعات ينحصرون بحدود منطقية.
  Future<Field> updateFieldInfo(
    Field field, {
    required String name,
    required String area,
    required String city,
    required Sport sport,
    required int pricePerHour,
    required int openHour,
    required int closeHour,
    required bool isOpen,
  }) async {
    final cleanName = InputSanitizer.clean(name, maxLength: 50);
    final cleanArea = InputSanitizer.clean(area, maxLength: 50);
    final cleanCity = InputSanitizer.clean(city, maxLength: 30);
    if (cleanName.isEmpty || cleanArea.isEmpty || cleanCity.isEmpty) {
      throw ArgumentError('الاسم والمنطقة والمدينة مطلوبين');
    }
    if (pricePerHour < 0 || pricePerHour > 1000000) {
      throw ArgumentError('السعر لازم يكون بين 0 ومليون دينار');
    }
    if (openHour < 0 || closeHour > 24 || openHour >= closeHour) {
      throw ArgumentError('ساعات الدوام غير منطقية');
    }
    return _saveOwnerUpdate(
      field,
      {
        'name': cleanName,
        'area': cleanArea,
        'city': cleanCity,
        'sport': sport.name,
        'pricePerHour': pricePerHour,
        'openHour': openHour,
        'closeHour': closeHour,
        'isOpen': isOpen,
      },
      field.copyWith(
        name: cleanName,
        area: cleanArea,
        city: cleanCity,
        sport: sport,
        pricePerHour: pricePerHour,
        openHour: openHour,
        closeHour: closeHour,
        isOpen: isOpen,
      ),
    );
  }

  // ---------- الوسائط ----------

  /// حفظ رابط موقع الملعب على خرائط Google — فارغ = حذف الرابط
  Future<Field> setMapsUrl(Field field, String url) async {
    final t = url.trim();
    if (t.isNotEmpty && !isValidHttpsUrl(t)) {
      throw ArgumentError('الرابط لازم يبدي بـ https');
    }
    return _saveOwnerUpdate(field, {'mapsUrl': t}, field.copyWith(mapsUrl: t));
  }

  /// رفع صور ترويجية — تظهر كبانر بصفحة الملعب
  Future<Field> addPromoPhotos(Field field, List<XFile> files) async {
    if (files.isEmpty) return field;
    final newUrls = await _uploadImages(field, 'field-promos', files);
    final updatedUrls = [...field.promoImageUrls, ...newUrls];
    return _saveOwnerUpdate(field, {
      'promoImageUrls': updatedUrls,
    }, field.copyWith(promoImageUrls: updatedUrls));
  }

  /// حذف صورة ترويجية
  Future<Field> removePromoPhoto(Field field, String url) async {
    final updatedUrls = [
      for (final u in field.promoImageUrls)
        if (u != url) u,
    ];
    final updated = await _saveOwnerUpdate(field, {
      'promoImageUrls': updatedUrls,
    }, field.copyWith(promoImageUrls: updatedUrls));
    await _deleteStorageFile(url);
    return updated;
  }

  /// رفع صور لقطات الملعب (هايلايتس)
  Future<Field> addHighlightPhotos(Field field, List<XFile> files) async {
    if (files.isEmpty) return field;
    final newUrls = await _uploadImages(field, 'field-highlights', files);
    final updatedHighlights = [
      ...field.highlights,
      for (final url in newUrls) FieldHighlight(url: url, isVideo: false),
    ];
    return _saveOwnerUpdate(field, {
      'highlights': [for (final h in updatedHighlights) h.toMap()],
    }, field.copyWith(highlights: updatedHighlights));
  }

  /// إضافة رابط فيديو (يوتيوب/انستغرام) للقطات الملعب
  Future<Field> addHighlightVideo(Field field, String url) async {
    final t = url.trim();
    if (!isValidVideoUrl(t)) {
      throw ArgumentError('الرابط لازم يكون https من يوتيوب أو انستغرام');
    }
    final updatedHighlights = [
      ...field.highlights,
      FieldHighlight(url: t, isVideo: true),
    ];
    return _saveOwnerUpdate(field, {
      'highlights': [for (final h in updatedHighlights) h.toMap()],
    }, field.copyWith(highlights: updatedHighlights));
  }

  /// حذف لقطة — صورة (تنحذف من Storage) أو رابط فيديو
  Future<Field> removeHighlight(Field field, FieldHighlight highlight) async {
    final updatedHighlights = [
      for (final h in field.highlights)
        if (h.url != highlight.url) h,
    ];
    final updated = await _saveOwnerUpdate(field, {
      'highlights': [for (final h in updatedHighlights) h.toMap()],
    }, field.copyWith(highlights: updatedHighlights));
    if (!highlight.isVideo) await _deleteStorageFile(highlight.url);
    return updated;
  }

  // ---------- الخدمات (مراكز العلاج خصوصاً) ----------

  /// الحد الأقصى لعدد الخدمات بالمنشأة الوحدة
  static const int maxServices = 20;

  /// تحديث خدمات المنشأة وأسعارها — الأسماء تنظّف بالـ sanitizer
  /// والأسعار تنحصر بحدود منطقية.
  Future<Field> updateServices(Field field, List<VenueService> services) async {
    if (services.length > maxServices) {
      throw ArgumentError('أقصى عدد خدمات هو $maxServices');
    }
    final cleaned = <VenueService>[];
    for (final s in services) {
      final name = InputSanitizer.clean(s.name, maxLength: 60);
      if (name.isEmpty) throw ArgumentError('اسم الخدمة مطلوب');
      if (s.price < 0 || s.price > 1000000) {
        throw ArgumentError('سعر الخدمة لازم يكون بين 0 ومليون دينار');
      }
      cleaned.add(VenueService(name: name, price: s.price));
    }
    return _saveOwnerUpdate(field, {
      'services': [for (final s in cleaned) s.toMap()],
    }, field.copyWith(services: cleaned));
  }

  // ---------- طرق الدفع ----------

  /// تحديث طرق الدفع المقبولة — لازم تبقى طريقة وحدة مفعّلة على الأقل.
  /// زين كاش واجهة فقط: ينحفظ التفعيل ومعرّف التاجر بس ما يشتغل دفع فعلي.
  Future<Field> updatePaymentMethods(
    Field field, {
    required bool deposit,
    required bool cashOnArrival,
    required bool zainCashEnabled,
    required String zainCashMerchantId,
  }) async {
    if (!deposit && !cashOnArrival) {
      throw ArgumentError('لازم تبقى طريقة دفع وحدة مفعّلة على الأقل');
    }
    final cleanMerchantId = InputSanitizer.clean(
      zainCashMerchantId,
      maxLength: 50,
    );
    if (zainCashEnabled && cleanMerchantId.isEmpty) {
      throw ArgumentError('فعّلت زين كاش؟ دخّل معرّف التاجر');
    }
    return _saveOwnerUpdate(
      field,
      {
        'paymentDeposit': deposit,
        'paymentCashOnArrival': cashOnArrival,
        'zainCashEnabled': zainCashEnabled,
        'zainCashMerchantId': cleanMerchantId,
      },
      field.copyWith(
        paymentDeposit: deposit,
        paymentCashOnArrival: cashOnArrival,
        zainCashEnabled: zainCashEnabled,
        zainCashMerchantId: cleanMerchantId,
      ),
    );
  }
}
