/// حالة اقتراح الملعب — من التقديم لين القرار
enum VenueSuggestionStatus {
  pending('قيد المراجعة'),
  added('انضاف'),
  rejected('مرفوض');

  const VenueSuggestionStatus(this.label);

  final String label;

  static VenueSuggestionStatus fromName(String? name) {
    return VenueSuggestionStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => VenueSuggestionStatus.pending,
    );
  }
}

/// اقتراح ملعب/منشأة من لاعب — ملعب ما موجود بالتطبيق بعد.
/// معرّف المستند مبني من اسم الملعب + منطقته (تطابق تقريبي)، فلو أكثر
/// من لاعب اقترح نفس الملعب يزيد [requestCount] بدل ما ينخلق سجل جديد.
class VenueSuggestion {
  const VenueSuggestion({
    required this.id,
    required this.name,
    required this.area,
    required this.userId,
    required this.requesterIds,
    required this.requestCount,
    required this.status,
    this.mapsUrl = '',
    this.phone = '',
    this.note = '',
    this.createdAtMs,
    this.updatedAtMs,
  });

  factory VenueSuggestion.fromMap(String id, Map<String, dynamic> data) {
    return VenueSuggestion(
      id: id,
      name: (data['name'] as String?) ?? '',
      area: (data['area'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      requesterIds: [
        for (final u in (data['requesterIds'] as List?) ?? const [])
          if (u is String && u.isNotEmpty) u,
      ],
      requestCount: (data['requestCount'] as num?)?.toInt() ?? 1,
      status: VenueSuggestionStatus.fromName(data['status'] as String?),
      mapsUrl: (data['mapsUrl'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      note: (data['note'] as String?) ?? '',
      createdAtMs: (data['createdAtMs'] as num?)?.toInt(),
      updatedAtMs: (data['updatedAtMs'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;

  /// المدينة/المنطقة كما كتبها اللاعب (نص حر)
  final String area;

  /// أول لاعب اقترح هذا الملعب
  final String userId;

  /// كل اللاعبين اللي طلبوا نفس الملعب — يمنع احتساب نفس اللاعب مرتين
  final List<String> requesterIds;

  /// چم لاعب طلب هذا الملعب — الأساس بترتيب لوحة الإدارة
  final int requestCount;
  final VenueSuggestionStatus status;

  /// رابط خرائط اختياري (https فقط)
  final String mapsUrl;

  /// رقم تواصل الملعب إن يعرفه اللاعب (اختياري، صيغة دولية +964...)
  final String phone;
  final String note;

  final int? createdAtMs;
  final int? updatedAtMs;

  Map<String, Object?> toMap() => {
    'name': name,
    'area': area,
    'userId': userId,
    'requesterIds': requesterIds,
    'requestCount': requestCount,
    'status': status.name,
    'mapsUrl': mapsUrl,
    'phone': phone,
    'note': note,
  };
}
