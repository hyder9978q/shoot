import 'package:flutter/material.dart';

/// نوع الإعلان — يحدد الأيقونة والتصنيف المعروض للاعبين
enum AdType {
  promo('عرض / خصم', Icons.local_offer_rounded),
  tournament('بطولة', Icons.emoji_events_rounded),
  news('خبر', Icons.campaign_rounded),
  availability('وقت متاح', Icons.event_available_rounded);

  const AdType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// إعلان منشور من صاحب منشأة — ينخزن بمجموعة ads بـ Firestore
class Ad {
  const Ad({
    required this.id,
    required this.fieldId,
    required this.ownerId,
    required this.fieldName,
    required this.title,
    required this.body,
    required this.type,
    required this.expiresAt,
    this.imageUrl = '',
    this.isActive = true,
    this.createdAtMs = 0,
  });

  factory Ad.fromMap(String id, Map<String, dynamic> data) {
    return Ad(
      id: id,
      fieldId: (data['fieldId'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      fieldName: (data['fieldName'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      type: AdType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => AdType.news,
      ),
      expiresAt: (data['expiresAt'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      createdAtMs: (data['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String fieldId;

  /// معرّف صاحب المنشأة — لفحص الملكية بالتطبيق وبقواعد Firestore
  final String ownerId;

  /// اسم المنشأة وقت النشر — يبقى ثابت حتى لو تغيّر اسمها بعدين
  final String fieldName;
  final String title;
  final String body;
  final AdType type;

  /// تاريخ انتهاء الإعلان بصيغة yyyy-MM-dd — بعده ما يظهر إطلاقاً
  final String expiresAt;

  /// صورة الإعلان (اختيارية) — فارغة = بدون صورة
  final String imageUrl;

  /// وقّفه صاحب المنشأة مؤقتاً؟ (منفصل عن انتهاء الصلاحية)
  final bool isActive;

  /// وقت النشر بالميلي ثانية — للترتيب (الأحدث أولاً)
  final int createdAtMs;

  Map<String, Object?> toMap() => {
    'fieldId': fieldId,
    'ownerId': ownerId,
    'fieldName': fieldName,
    'title': title,
    'body': body,
    'type': type.name,
    'expiresAt': expiresAt,
    'imageUrl': imageUrl,
    'isActive': isActive,
    'createdAtMs': createdAtMs,
  };

  /// منتهي الصلاحية؟ بالمقارنة مع تاريخ اليوم (yyyy-MM-dd)
  bool isExpiredAt(String today) => expiresAt.compareTo(today) < 0;

  /// نشيط وظاهر فعلاً للاعبين؟ (مفعّل وغير منتهي)
  bool isVisibleAt(String today) => isActive && !isExpiredAt(today);

  Ad copyWith({
    String? title,
    String? body,
    AdType? type,
    String? expiresAt,
    String? imageUrl,
    bool? isActive,
  }) {
    return Ad(
      id: id,
      fieldId: fieldId,
      ownerId: ownerId,
      fieldName: fieldName,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      expiresAt: expiresAt ?? this.expiresAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAtMs: createdAtMs,
    );
  }
}
