// fcm_service.dart
// 알림 여부
// fireabase 저장
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  FcmService({required this.flutterLocalNotificationsPlugin});

  Future<void> initTimeZone() async {
    tz.initializeTimeZones();
  }

  Future<void> initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
  }

  /// 🔔 Android 12+ Exact Alarm 권한 요청
  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid && (await Permission.scheduleExactAlarm.isDenied)) {
      await Permission.scheduleExactAlarm.request();
      print('🔔 Exact Alarm 권한 요청 완료');
    }
  }

  Future<void> scheduleNotification(
    String id,
    String title,
    String body,
    DateTime scheduledDate,
  ) async {
    final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    print(
      '🛎️ scheduleNotification 호출 - id: $id, title: $title, 예약시간: ${scheduledTZDate.toLocal()}',
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id.hashCode,
      title,
      body,
      scheduledTZDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_channel_id',
          'Todo Notifications',
          channelDescription: '일정 알림',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> cancelNotification(String id) async {
    print('🛑 cancelNotification 호출 - id: $id');
    await flutterLocalNotificationsPlugin.cancel(id.hashCode);
  }

  Future<void> requestPermission() async {
    try {
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
    } catch (e) {
      print('⚠️ 알림 권한 요청 실패: $e');
    }
  }

  Future<void> saveTokenToFirestore() async {
    try {
      final String? token = await _messaging.getToken();
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) return;
      if (token == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcm_token': token,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM 토큰 Firestore 저장 완료: $token');
    } catch (e) {
      print('⚠️ FCM 토큰 저장 실패: $e');
    }
  }

  void setupInteractedMessage(BuildContext context) {
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) Navigator.pushNamed(context, '/home');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Navigator.pushNamed(context, '/home');
    });
  }

  void listenForegroundMessages(BuildContext context) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final title = message.notification!.title ?? '';
        final body = message.notification!.body ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            action: SnackBarAction(
              label: '열기',
              onPressed: () => Navigator.pushNamed(context, '/home'),
            ),
          ),
        );
      }
    });
  }

  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    print('📡 백그라운드 메시지 수신: ${message.messageId}');
  }
}
