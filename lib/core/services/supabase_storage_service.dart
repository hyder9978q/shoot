import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// خدمة رفع الصور على Supabase Storage عبر REST مباشرة
/// (بدون حزمة supabase_flutter — نحتاج التخزين فقط، والمصادقة تبقى Firebase).
///
/// كل الـ buckets (field-photos, field-promos, field-highlights,
/// player-photos, ad-images) عامة القراءة، بحد ٥ ميغا وأنواع صور فقط
/// (مفروضة من السيرفر على مستوى الـ bucket نفسه).
///
/// الحذف مو موجود عمداً: مفتاح anon مضمّن بالتطبيق ويگدر أي شخص
/// يستخرجه، فسياسة DELETE بالسيرفر تعني إن أي واحد يمحي صور كل
/// الملاعب. بدالها التطبيق يشيل رابط الصورة من Firestore فقط —
/// الصورة تختفي من كل الشاشات، وملفها يبقى بالتخزين بلا ضرر.
class SupabaseStorageService {
  SupabaseStorageService._();

  static const String _projectUrl = 'https://zityywrwmldiyeskxrgs.supabase.co';

  /// مفتاح anon العام — آمن للتضمين بالتطبيق (صلاحياته محكومة بسياسات RLS)
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppdHl5d3J3bWxkaXllc2t4cmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMjkzNzYsImV4cCI6MjA5MjYwNTM3Nn0.n3hU91EQEnKjFONAYpIDZSC1zBB1XKjFV1DYwTZwueo';

  static Map<String, String> _headers(String contentType) => {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
        'Content-Type': contentType,
      };

  /// يرفع صورة للـ bucket ويرجّع رابطها العام
  static Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final uri = Uri.parse('$_projectUrl/storage/v1/object/$bucket/$path');
    final res = await http
        .post(uri, headers: _headers(contentType), body: bytes)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw StateError('فشل رفع الصورة (${res.statusCode})');
    }
    return '$_projectUrl/storage/v1/object/public/$bucket/$path';
  }

  /// هل الرابط تابع لتخزين مشروعنا؟
  static bool ownsUrl(String url) =>
      url.startsWith('$_projectUrl/storage/v1/object/public/');
}
