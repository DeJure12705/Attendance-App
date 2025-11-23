import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendanceapp/model/user.dart';

class MessagingService {
  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    await _fm.requestPermission();
    final token = await _fm.getToken();
    if (token != null && User.uid.isNotEmpty) {
      User.fcmToken = token;
      await _db.collection('Users').doc(User.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
    // Listen for token refresh
    _fm.onTokenRefresh.listen((newToken) async {
      if (User.uid.isEmpty) return;
      User.fcmToken = newToken;
      await _db.collection('Users').doc(User.uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    });
  }
}
