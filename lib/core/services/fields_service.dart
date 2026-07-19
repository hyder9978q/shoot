import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/field.dart';
import '../utils/input_sanitizer.dart';

/// ملف مرفوض عند الرفع — مو صورة أو حجمه أكبر من المسموح
class InvalidImageException implements Exception {
  const InvalidImageException({required this.tooLarge});

  /// true = الحجم أكبر من الحد، false = نوع الملف مو صورة مقبولة
  final bool tooLarge;
}

/// خدمة الملاعب — تقرأ من Firestore، ومع أي خلل (لا نت / لا Firebase)
/// ترجع للبيانات التجريبية حتى يبقى التطبيق شغال.
class FieldsService {
  FieldsService._();

  static final FieldsService instance = FieldsService._();

  /// آخر قائمة محمّلة — البحث والفلترة يشتغلون عليها فورياً
  List<Field>? _cache;

  /// تحميل الملاعب (مرة وحدة، وتنخزن بالذاكرة)
  Future<List<Field>> loadFields() async {
    final cached = _cache;
    if (cached != null) return cached;

    if (Firebase.apps.isEmpty) return _cache = _mockFields;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fields')
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));
      final fields = [
        for (final doc in snapshot.docs) Field.fromMap(doc.id, doc.data()),
      ]..sort((a, b) => b.rating.compareTo(a.rating));
      return _cache = fields.isEmpty ? _mockFields : fields;
    } catch (_) {
      // بدون نت أو أي خطأ: نرجع للبيانات التجريبية بدل شاشة فارغة
      return _cache = _mockFields;
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
  ];

  /// ملاعب المستخدم الحالي (إذا هو صاحب ملعب) — فارغة للاعب العادي
  Future<List<Field>> myFields(String userId) async {
    if (userId.isEmpty) return const [];
    final fields = await loadFields();
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
      final matchesQuery = q.isEmpty ||
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
  static bool get canUploadPhotos => Firebase.apps.isNotEmpty;

  /// فحص الملكية: ما نسمح بأي تعديل على ملعب مو تابع للمستخدم الحالي.
  /// (قواعد Firestore/Storage تمنعه من السيرفر — وهذا خط دفاع بالتطبيق)
  void _assertOwner(Field field) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || field.ownerId != uid) {
      throw StateError('غير مخوّل: هذا الملعب مو تابع لحسابك');
    }
  }

  /// يبدّل الملعب بالذاكرة بنسخة محدّثة حتى تنعكس الصور بكل الشاشات فوراً
  void _replaceInCache(Field updated) {
    final list = _cache;
    if (list == null) return;
    final i = list.indexWhere((f) => f.id == updated.id);
    if (i != -1) list[i] = updated;
  }

  /// الحد الأقصى لحجم الصورة الواحدة: ٥ ميغابايت
  static const int maxPhotoBytes = 5 * 1024 * 1024;

  /// أنواع الصور المقبولة فقط — أي امتداد ثاني يُرفض
  static const Map<String, String> _allowedImageTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// يتحقق من الملف على مستوى التطبيق قبل الرفع:
  /// امتداد صورة مقبول + حجم ≤ ٥ ميغا. يرجّع (الامتداد، البايتات).
  static Future<(String, Uint8List)> _validateImage(XFile file) async {
    final dot = file.name.lastIndexOf('.');
    final ext = dot == -1 ? '' : file.name.substring(dot + 1).toLowerCase();
    if (!_allowedImageTypes.containsKey(ext)) {
      throw const InvalidImageException(tooLarge: false);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxPhotoBytes) {
      throw const InvalidImageException(tooLarge: true);
    }
    return (ext, bytes);
  }

  /// يرفع صوراً جديدة للملعب على Firebase Storage ويحفظ روابطها بـ Firestore.
  /// يرجّع الملعب بنسخته المحدّثة (بكل الصور). يرمي استثناء عند الفشل.
  Future<Field> addFieldPhotos(Field field, List<XFile> files) async {
    if (!canUploadPhotos) {
      throw StateError('رفع الصور يحتاج التطبيق المنشور (مو وضع التجربة)');
    }
    _assertOwner(field);
    if (files.isEmpty) return field;

    // نتحقق من كل الملفات قبل ما نرفع أي واحد — يا كلها صالحة يا ولا وحدة
    final validated = [for (final file in files) await _validateImage(file)];

    final storage = FirebaseStorage.instance;
    final newUrls = <String>[];
    for (final (ext, bytes) in validated) {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final ref = storage.ref('field_photos/${field.id}/$stamp.$ext');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _allowedImageTypes[ext]),
      );
      newUrls.add(await ref.getDownloadURL());
    }

    final updatedUrls = [...field.imageUrls, ...newUrls];
    await FirebaseFirestore.instance
        .collection('fields')
        .doc(field.id)
        .set({'imageUrls': updatedUrls}, SetOptions(merge: true));

    final updated = field.copyWith(imageUrls: updatedUrls);
    _replaceInCache(updated);
    return updated;
  }

  /// يحذف صورة من الملعب — من Firestore ومن Storage.
  /// يرجّع الملعب بنسخته المحدّثة. يرمي استثناء عند الفشل.
  Future<Field> removeFieldPhoto(Field field, String url) async {
    if (!canUploadPhotos) {
      throw StateError('حذف الصور يحتاج التطبيق المنشور (مو وضع التجربة)');
    }
    _assertOwner(field);

    final updatedUrls = [
      for (final u in field.imageUrls)
        if (u != url) u,
    ];
    await FirebaseFirestore.instance
        .collection('fields')
        .doc(field.id)
        .set({'imageUrls': updatedUrls}, SetOptions(merge: true));

    // حذف الملف نفسه — لو فشل (رابط قديم مثلاً) ما نكسر العملية
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}

    final updated = field.copyWith(imageUrls: updatedUrls);
    _replaceInCache(updated);
    return updated;
  }
}
