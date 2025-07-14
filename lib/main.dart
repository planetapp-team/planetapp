// main.dart
// 기능:
// - Firebase 초기화 및 Firebase Cloud Messaging(FCM) 백그라운드 메시지 처리
// - 포그라운드 및 백그라운드 푸시 알림 수신 시 SnackBar 표시 및 화면 전환 처리
// - FCM 토큰 Firestore 저장 및 권한 요청 관리
// - 앱 주요 화면 라우팅 설정 및 로그인 상태 분기(AuthGate 사용)

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'services/fcm_service.dart'; // FCM 관련 서비스 클래스
import 'auth_gate.dart'; // 로그인 상태 분기용 위젯

// 주요 화면 임포트
import 'auth_test_page.dart';
import 'home_page.dart';
import 'pages/profile_page.dart';
import 'pages/change_password_page.dart';
import 'pages/todo_test_page.dart'; // 할일 관리 페이지
import 'pages/filter_page.dart';
import 'calendar_page.dart';
import 'natural_input_page.dart'; // 자연어 입력 페이지

// 일정 수정 페이지 임포트
import 'pages/edit_todo_page.dart';

// 백그라운드 상태에서 FCM 메시지 수신 시 호출되는 핸들러 함수
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase 초기화 (백그라운드에서 앱이 완전히 종료된 상태라도 Firebase 초기화 필요)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('💬 백그라운드 푸시 수신: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 푸시 알림 클릭 시 앱이 열리면서 호출되는 리스너 등록
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('💬 푸시 알림 클릭: ${message.messageId}');
    // TODO: 푸시 알림 클릭 시 특정 화면으로 이동하는 로직 추가 필요
    // 예: Navigator.pushNamed(context, '/home');
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FcmService _fcmService = FcmService(); // FCM 서비스 인스턴스 생성

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  // FCM 초기화 및 권한 요청, 토큰 저장, 메시지 수신 리스너 설정
  void _initializeFCM() {
    _fcmService.requestPermission(); // 알림 권한 요청
    _fcmService.saveTokenToFirestore(); // FCM 토큰 Firestore 저장
    _fcmService.listenForegroundMessages(context); // 포그라운드 메시지 수신 리스너
    _fcmService.setupInteractedMessage(context); // 앱이 푸시 알림으로 열렸을 때 처리
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
      home: const AuthGate(), // 로그인 여부에 따른 화면 분기 처리
      // 앱 라우트 설정
      routes: {
        '/login': (context) => const AuthTestPage(), // 로그인 화면
        '/home': (context) => HomePage(), // 홈 화면
        '/profile': (context) => const ProfilePage(), // 프로필 화면
        '/changePassword': (context) =>
            const ChangePasswordPage(), // 비밀번호 변경 화면
        '/todo_manage': (context) => const TodoTestPage(), // 할일 관리 화면 (별칭)
        '/todo_test': (context) => const TodoTestPage(), // 할일 관리 화면
        '/filter': (context) => const FilterPage(), // 필터 페이지
        '/calendar': (context) => const CalendarPage(), // 캘린더 페이지
        '/natural_input': (context) => NaturalInputPage(
          // 자연어 입력 페이지
          selectedDate: DateTime.now(),
          onDateSelected: (DateTime selectedDate) {
            print('Selected Date: $selectedDate');
          },
        ),

        // 일정 수정 페이지 라우팅 (arguments로 todoData 전달 필요)
        '/edit_todo': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return EditTodoPage(todoData: args);
        },
      },
    );
  }
}
