//main.dart
//푸시 알림 클릭 시 화면 전환, 푸시 알림 수신 시 SnackBar 표시,
// FCM 토큰 Firestore 저장 등 포함

//main.dart
//푸시 알림 클릭 시 화면 전환, 푸시 알림 수신 시 SnackBar 표시,
// FCM 토큰 Firestore 저장 등 포함
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'services/fcm_service.dart'; // FCM 서비스 클래스
import 'auth_gate.dart'; // 로그인 상태 분기

// 주요 화면 import
import 'auth_test_page.dart';
import 'home_page.dart';
import 'pages/profile_page.dart';
import 'pages/change_password_page.dart';
import 'pages/todo_test_page.dart';
import 'pages/filter_page.dart';
import 'calendar_page.dart';
import 'natural_input_page.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('💬 백그라운드 푸시 수신: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FcmService _fcmService = FcmService();

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  void _initializeFCM() {
    _fcmService.requestPermission();
    _fcmService.saveTokenToFirestore();
    _fcmService.listenForegroundMessages(context);
    _fcmService.setupInteractedMessage(context);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '할일 일정 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
      routes: {
        '/login': (context) => const AuthTestPage(),
        '/home': (context) => HomePage(), // const 제거
        '/profile': (context) => const ProfilePage(),
        '/changePassword': (context) => const ChangePasswordPage(),
        '/todo_test': (context) => const TodoTestPage(),
        '/filter': (context) => const FilterPage(),
        '/calendar': (context) => const CalendarPage(),
        '/natural_input': (context) => const NaturalInputPage(),
      },
    );
  }
}
