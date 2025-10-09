// main.dart
// 기능:
// - Firebase 초기화 및 Firebase Cloud Messaging(FCM) 백그라운드 메시지 처리
// - 포그라운드 및 백그라운드 푸시 알림 수신 시 SnackBar 표시 및 화면 전환 처리
// - FCM 토큰 Firestore 저장 및 권한 요청 관리
// - flutter_local_notifications 초기화 (로컬 알림)
// - 앱 주요 화면 라우팅 설정 및 로그인 상태 분기(AuthGate 사용)
// - SplashScreen → AuthGate 진입 추가
// - 전체 화면 배경색 하얀색 적용, 상단 상태바 색상 흰색으로 설정, AppBarTheme 적용

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'auth_gate.dart';
import 'splash_screen.dart'; // ✅ 추가 (스플래시 화면)

// 주요 화면 임포트
import 'auth_test_page.dart'; // 로그인/회원가입 화면
import 'home_page.dart'; // 홈 화면
import 'pages/profile_page.dart'; // 프로필 (설정) 화면
import 'pages/change_password_page.dart'; // 비밀번호 재설정 화면
import 'pages/todo_test_page.dart'; // 일정 리스트 화면
import 'pages/filter_page.dart'; // 검색 화면
import 'calendar_page.dart'; // 캘린더 화면
import 'natural_input_page.dart'; // 자연어 일정 추가 화면
// import 'pages/edit_todo_page.dart'; // 일정 수정 화면

// flutter_local_notifications 플러그인 인스턴스 (전역)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 네비게이터 키 추가: 푸시 알림 클릭 시 화면 전환에 사용
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 백그라운드 상태에서 FCM 메시지 수신 시 호출되는 핸들러 함수
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('💬 백그라운드 푸시 수신: ${message.messageId}');
}

// flutter_local_notifications 초기화 함수
Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 전체 상태바 색상 흰색, 아이콘 색상 검정으로 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS용
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  tz.initializeTimeZones();

  await initializeLocalNotifications();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('💬 푸시 알림 클릭: ${message.messageId}');
    navigatorKey.currentState?.pushNamed('/home');
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FcmService _fcmService = FcmService(
    flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
  );

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
      title: '캠비',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.white, // ✅ 전체 화면 배경색 하얀색
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // AppBar 배경 흰색
          foregroundColor: Colors.black, // AppBar 글씨/아이콘 검정
          elevation: 0, // 그림자 제거
          systemOverlayStyle: SystemUiOverlayStyle.dark, // 상태바 아이콘 검정
        ),
      ),
      // ✅ 앱 첫 화면을 SplashScreen으로 설정
      home: SplashScreen(),
      routes: {
        '/login': (context) => const AuthTestPage(),
        '/home': (context) => HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/resetPassword': (context) => const ChangePasswordPage(),
        '/todo_manage': (context) => const TodoTestPage(),
        '/todo_test': (context) => const TodoTestPage(),
        '/filter': (context) => const FilterPage(),
        '/calendar': (context) => const CalendarPage(),
        '/natural_input': (context) => NaturalInputPage(
          selectedDate: DateTime.now(),
          onDateSelected: (DateTime selectedDate) {
            print('Selected Date: $selectedDate');
          },
        ),
        // '/edit_todo': (context) {
        //   final args =
        //       ModalRoute.of(context)!.settings.arguments
        //           as Map<String, dynamic>;
        //   return EditTodoPage(todoData: args);
        // },
      },
    );
  }
}

// 마감 5분 전에 로컬 알림 예약 함수
Future<void> scheduleDeadlineNotification(DateTime deadlineTime) async {
  final scheduledTime = tz.TZDateTime.from(
    deadlineTime,
    tz.local,
  ).subtract(const Duration(minutes: 5));

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    '📌 마감 5분 전 알림',
    '5분 뒤 마감될 일정이 있어요!',
    scheduledTime,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'deadline_channel',
        '마감 알림',
        channelDescription: '마감 시간 전에 알림을 보냅니다',
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
