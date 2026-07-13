import 'package:cloud_firestore/cloud_firestore.dart' hide Field;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/field.dart';
import '../models/player_request.dart';
import 'bookings_service.dart';

/// خدمة إعلانات "ناقصنا لاعب" — تقرأ وتكتب بمجموعة playerRequests
/// وبوضع الاختبار (بدون Firebase) تشتغل على بيانات تجريبية بالذاكرة.
class PlayerRequestsService {
  PlayerRequestsService._();

  static final PlayerRequestsService instance = PlayerRequestsService._();

  /// يزيد مع كل نشر/حذف — التبويب يسمعه ويحدّث نفسه
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get _useMock => Firebase.apps.isEmpty;

  String get currentUserId => _useMock
      ? 'mock-user'
      : FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _currentPhone => _useMock
      ? '+9647701234567'
      : FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

  /// إعلانات تجريبية (من أشخاص ثانين) حتى التبويب يبين حي بالتجربة
  late final List<PlayerRequest> _mockRequests = [
    PlayerRequest(
      id: 'r1',
      userId: 'other-user-1',
      phone: '+9647709998877',
      sport: Sport.football,
      place: 'ملعب النجوم — المنصور',
      date: BookingsService.todayDate(),
      hour: 20,
      playersNeeded: 2,
      note: 'المستوى وسط، اللعبة ودّية',
    ),
    PlayerRequest(
      id: 'r2',
      userId: 'other-user-2',
      phone: '+9647801112233',
      sport: Sport.padel,
      place: 'بادل هاوس — الجادرية',
      date: BookingsService.todayDate(),
      hour: 18,
      playersNeeded: 1,
    ),
  ];

  /// إعلانات اليوم المفتوحة — الأقرب وقتاً أولاً
  Future<List<PlayerRequest>> todayRequests() async {
    if (_useMock) {
      final list = [..._mockRequests]..sort((a, b) => a.hour.compareTo(b.hour));
      return list;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('playerRequests')
        .where('date', isEqualTo: BookingsService.todayDate())
        .get()
        .timeout(const Duration(seconds: 10));
    final requests = [
      for (final doc in snapshot.docs)
        PlayerRequest.fromMap(doc.id, doc.data()),
    ]..sort((a, b) => a.hour.compareTo(b.hour));
    return requests;
  }

  /// نشر إعلان جديد لليوم
  Future<void> createRequest({
    required Sport sport,
    required String place,
    required int hour,
    required int playersNeeded,
    String note = '',
  }) async {
    final request = PlayerRequest(
      id: '',
      userId: currentUserId,
      phone: _currentPhone,
      sport: sport,
      place: place.trim(),
      date: BookingsService.todayDate(),
      hour: hour,
      playersNeeded: playersNeeded,
      note: note.trim(),
    );

    if (_useMock) {
      _mockRequests.add(PlayerRequest.fromMap(
        'mock-${_mockRequests.length}',
        request.toMap(),
      ));
      revision.value++;
      return;
    }

    await FirebaseFirestore.instance.collection('playerRequests').add({
      ...request.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 15));
    revision.value++;
  }

  /// حذف إعلاني (من يكتمل الفريق)
  Future<void> deleteRequest(PlayerRequest request) async {
    if (_useMock) {
      _mockRequests.removeWhere((r) => r.id == request.id);
      revision.value++;
      return;
    }

    await FirebaseFirestore.instance
        .collection('playerRequests')
        .doc(request.id)
        .delete()
        .timeout(const Duration(seconds: 15));
    revision.value++;
  }
}
