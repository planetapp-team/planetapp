// lib/services/fcm_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 🔔 사용자에게 알림 권한 요청
  Future<void> requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔔 알림 권한 허용됨');
    } else {
      print('❌ 알림 권한 거부됨');
    }
  }

  /// 📬 현재 사용자의 FCM 토큰을 Firestore에 저장
  Future<void> saveTokenToFirestore() async {
    try {
      final String? token = await _messaging.getToken();
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcm_token': token,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('✅ FCM 토큰 Firestore 저장 완료: $token');
      }
    } catch (e) {
      print('⚠️ FCM 토큰 저장 실패: $e');
    }
  }

  /// 📲 앱이 종료 상태 또는 백그라운드 상태에서 알림을 클릭했을 때 처리
  void setupInteractedMessage(BuildContext context) {
    // 종료 상태에서 클릭된 메시지
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('✅ 앱 종료 상태에서 알림 클릭됨');
        Navigator.pushNamed(context, '/home');
      }
    });

    // 백그라운드 상태에서 클릭된 메시지
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('✅ 앱 백그라운드 상태에서 알림 클릭됨');
      Navigator.pushNamed(context, '/home');
    });
  }

  /// 🔔 앱이 실행 중일 때 푸시 알림 수신 처리 (포그라운드)
  void listenForegroundMessages(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📥 포그라운드 알림 수신');

      if (message.notification != null) {
        final title = message.notification!.title ?? '';
        final body = message.notification!.body ?? '';

        print('🔔 제목: $title');
        print('📝 내용: $body');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            action: SnackBarAction(
              label: '열기',
              onPressed: () {
                Navigator.pushNamed(context, '/home');
              },
            ),
          ),
        );
      }
    });
  }

  /// 💤 백그라운드 메시지 핸들러 (main.dart에서 등록해야 함)
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('📡 백그라운드 메시지 수신: ${message.messageId}');
  }
}
