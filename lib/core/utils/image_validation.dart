import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// ملف مرفوض عند الرفع — مو صورة أو حجمه أكبر من المسموح
class InvalidImageException implements Exception {
  const InvalidImageException({required this.tooLarge});

  /// true = الحجم أكبر من الحد، false = نوع الملف مو صورة مقبولة
  final bool tooLarge;
}

/// تحقق موحّد من الصور والروابط — تستخدمه كل نقاط الرفع بالتطبيق
/// (صور الملاعب، لقطاتها، وصورة الملف الشخصي) حتى القيود توحّد بمكان
/// وحد وما تنفلت نقطة إدخال بدون فحص.
class ImageValidation {
  ImageValidation._();

  /// الحد الأقصى لحجم الصورة الواحدة: ٥ ميغابايت
  static const int maxBytes = 5 * 1024 * 1024;

  /// أنواع الصور المقبولة فقط — أي امتداد ثاني يُرفض
  static const Map<String, String> allowedTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// يتحقق من ملف صورة قبل الرفع: امتداد مقبول + حجم ≤ ٥ ميغا.
  /// يرجّع (الامتداد، نوع المحتوى، البايتات) أو يرمي [InvalidImageException].
  static Future<(String ext, String contentType, Uint8List bytes)> validate(
    XFile file,
  ) async {
    final dot = file.name.lastIndexOf('.');
    final ext = dot == -1 ? '' : file.name.substring(dot + 1).toLowerCase();
    final contentType = allowedTypes[ext];
    if (contentType == null) {
      throw const InvalidImageException(tooLarge: false);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const InvalidImageException(tooLarge: true);
    }
    return (ext, contentType, bytes);
  }

  /// رابط آمن؟ https فقط، بدون فراغات أو رموز خطيرة، وطول معقول
  static bool isValidHttpsUrl(String url) {
    final t = url.trim();
    if (t.isEmpty || t.length > 500) return false;
    if (RegExp(r'''[\s<>"'\\{}|^`]''').hasMatch(t)) return false;
    final uri = Uri.tryParse(t);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  /// المضيفات المسموحة لروابط الفيديو (يوتيوب وانستغرام فقط)
  static const List<String> allowedVideoHosts = [
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'youtu.be',
    'instagram.com',
    'www.instagram.com',
  ];

  /// رابط فيديو مقبول للهايلايتس؟ https + يوتيوب أو انستغرام فقط
  static bool isValidVideoUrl(String url) {
    if (!isValidHttpsUrl(url)) return false;
    final host = Uri.parse(url.trim()).host.toLowerCase();
    return allowedVideoHosts.contains(host);
  }
}
