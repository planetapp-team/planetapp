// lib/services/fcm_service.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 🔔 사용자에게 푸시 알림 권한 요청
  Future<void> requestPermission() async {
    try {
      // 알림 권한 요청: alert, badge, sound 등 모두 허용 요청
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 권한 허용 여부 확인
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('🔔 알림 권한 허용됨');
      } else {
        print('❌ 알림 권한 거부됨');
      }
    } catch (e) {
      print('⚠️ 알림 권한 요청 실패: $e');
    }
  }

  /// 📬 현재 로그인한 사용자의 FCM 토큰을 Firestore 'users' 컬렉션에 저장
  Future<void> saveTokenToFirestore() async {
    try {
      final String? token = await _messaging.getToken(); // FCM 토큰 얻기
      final User? user = FirebaseAuth.instance.currentUser; // 현재 로그인 유저

      if (user == null) {
        print('❌ 로그인되지 않은 사용자');
        return; // 로그인 안된 경우 함수 종료
      }

      if (token == null) {
        print('⚠️ FCM 토큰을 가져올 수 없음');
        return; // 토큰을 못가져오면 종료
      }

      // Firestore에 토큰과 업데이트 시간 저장 (기존 데이터 유지하며 병합)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcm_token': token,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM 토큰 Firestore 저장 완료: $token');
    } catch (e) {
      print('⚠️ FCM 토큰 저장 실패: $e');
    }
  }

  /// 📲 앱이 종료(종료 상태) 혹은 백그라운드 상태에서 알림 클릭 시 동작 설정
  void setupInteractedMessage(BuildContext context) {
    // 앱 종료 상태에서 알림 클릭 시 getInitialMessage가 메시지를 반환
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('✅ 앱 종료 상태에서 알림 클릭됨');
        Navigator.pushNamed(context, '/home'); // 홈 화면으로 이동
      }
    });

    // 백그라운드 상태에서 알림 클릭 시 호출되는 리스너
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('✅ 앱 백그라운드 상태에서 알림 클릭됨');
      Navigator.pushNamed(context, '/home'); // 홈 화면으로 이동
    });
  }

  /// 🔔 앱이 실행 중(포그라운드)일 때 푸시 알림 수신 처리
  void listenForegroundMessages(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📥 포그라운드 알림 수신');

      if (message.notification != null) {
        final title = message.notification!.title ?? '';
        final body = message.notification!.body ?? '';

        print('🔔 제목: $title');
        print('📝 내용: $body');

        // 화면에 스낵바 형태로 알림 내용 표시, '열기' 버튼 누르면 홈으로 이동
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

  /// 💤 백그라운드 메시지 수신 시 호출되는 핸들러 (main.dart에서 별도로 등록 필요)
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('📡 백그라운드 메시지 수신: ${message.messageId}');
    // 여기서 필요한 백그라운드 작업 추가 가능
  }
}
