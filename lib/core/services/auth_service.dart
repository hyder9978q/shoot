import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'app_mode.dart';
import 'local_store.dart';

/// خدمة تسجيل الدخول برقم الهاتف
///
/// إذا Firebase مرتبط وشغّال → ترسل رمز حقيقي عبر Firebase Auth.
/// إذا لا (مثلاً بالاختبارات الآلية أو وضع التطوير) → ترجع للوضع
/// التجريبي برمز 123456 — وهذا الرمز ما يشتغل إطلاقاً ببناء الإنتاج
/// (يتحكم فيه [AppMode.isMock]، مقفل بـ kDebugMode وقت الترجمة).
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// الرمز التجريبي — يشتغل بس بالوضع التجريبي
  static const String _mockOtp = '123456';

  bool get _useFirebase => !AppMode.isMock;

  /// معرّف جلسة التحقق (sessionInfo / verificationId)
  String? _verificationId;

  /// آخر إرسال ناجح لكل رقم — منع إعادة الإرسال قبل ٦٠ ثانية
  /// (خط دفاع بالخدمة نفسها، فوق عدّاد الواجهة)
  final Map<String, DateTime> _lastOtpSend = {};
  static const Duration _otpCooldown = Duration(seconds: 60);

  /// إرسال جاري؟ ما نرسل طلب ثاني والأول لسا شغال
  bool _sendingOtp = false;

  /// هل رقم الموبايل عراقي صحيح؟ (يبدي بـ 07 وطوله 11 رقم)
  static bool isValidIraqiPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^07\d{9}$').hasMatch(cleaned);
  }

  /// تحويل الرقم العراقي للصيغة الدولية: 07701234567 → +9647701234567
  static String toE164(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\s'), '');
    return '+964${cleaned.substring(1)}';
  }

  /// إرسال رمز التحقق
  Future<void> sendOtp(String phone) async {
    if (!isValidIraqiPhone(phone)) {
      throw FirebaseAuthException(code: 'invalid-phone-number');
    }
    if (_sendingOtp) return;
    final lastSend = _lastOtpSend[phone];
    if (lastSend != null &&
        DateTime.now().difference(lastSend) < _otpCooldown) {
      throw FirebaseAuthException(code: 'too-many-requests');
    }

    if (!_useFirebase) {
      await Future.delayed(const Duration(seconds: 1));
      _lastOtpSend[phone] = DateTime.now();
      return;
    }

    _sendingOtp = true;
    try {
      await _sendOtp(phone);
      _lastOtpSend[phone] = DateTime.now();
    } finally {
      _sendingOtp = false;
    }
  }

  Future<void> _sendOtp(String phone) async {
    final e164 = toE164(phone);
    if (kIsWeb) {
      // على الويب نستخدم واجهة Firebase المباشرة (REST) بدل نافذة reCAPTCHA
      // لأن نافذة "أنا مو روبوت" بمكتبة الويب تعلّگ أحياناً بدون جواب.
      // أرقام التجربة تنقبل بدون فحص روبوت. الأرقام الحقيقية تحتاج
      // تفعيل فوترة، وساعتها نضيف App Check أو recaptchaToken هنا.
      await _sendOtpViaRest(e164);
    } else {
      // على الموبايل: نستخدم verifyPhoneNumber وننتظر إشعار الإرسال
      final completer = Completer<void>();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          // أندرويد ممكن يقرأ الرمز وحده — نسجّل الدخول مباشرة
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await LocalStore.setSignedIn(true);
          } catch (_) {}
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        codeSent: (verificationId, _) {
          _verificationId = verificationId;
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
        },
      );
      await completer.future;
    }
  }

  Future<void> _sendOtpViaRest(String e164) async {
    final apiKey = Firebase.app().options.apiKey;
    final response = await http
        .post(
          Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=$apiKey',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phoneNumber': e164}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      _verificationId = jsonDecode(response.body)['sessionInfo'] as String?;
      return;
    }

    final body = response.body;
    final code = body.contains('BILLING_NOT_ENABLED')
        ? 'billing-not-enabled'
        : body.contains('INVALID_PHONE_NUMBER')
        ? 'invalid-phone-number'
        : body.contains('TOO_MANY')
        ? 'too-many-requests'
        : body.contains('OPERATION_NOT_ALLOWED')
        ? 'operation-not-allowed'
        : 'send-failed';
    // ما نمرّر جسم الرد الخام — ممكن يحتوي رقم الهاتف ويتسرب لأي معالج أخطاء
    throw FirebaseAuthException(code: code);
  }

  /// التحقق من الرمز — يرجع true إذا صحيح
  Future<bool> verifyOtp(String code) async {
    if (!_useFirebase) {
      await Future.delayed(const Duration(milliseconds: 800));
      final ok = code.trim() == _mockOtp;
      // بالوضع التجريبي ماكو جلسة Firebase — نثبّت الجلسة محلياً
      if (ok) await LocalStore.setSignedIn(true);
      return ok;
    }

    final verificationId = _verificationId;
    if (verificationId == null) return false;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // نجح الدخول: نمسح معرّف الجلسة فوراً — ما نخليه بالذاكرة أكثر من اللازم
      _verificationId = null;
      await LocalStore.setSignedIn(true);
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    // نمسح الجلسة المحلية قبل خروج Firebase حتى حارس الجلسة
    // بالهيكل الرئيسي يلگاها ممسوحة ويوجّه لشاشة الدخول
    await LocalStore.setSignedIn(false);
    if (_useFirebase) await FirebaseAuth.instance.signOut();
    _verificationId = null;
  }
}
