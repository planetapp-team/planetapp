// lib/home_page.dart
// 앱의 홈(메인) 화면

//  수정 사항
// - 시작일~마감일 사이에 오늘이 포함된 일정도 "오늘 마감 일정"에 포함되도록 변경
// - 알림 여부 on/off에 따라 반영 (기존 유지)
// - 오늘 마감 일정 팝업에서 4개 이상일 때만 스크롤
// - 팝업창 제목에서 (n건) 제거
// - 오늘 마감 일정 카드 배경 빨강, 글씨 검정, 클릭 시 팝업
// - 전체 알림 OFF 시 배너 자체 숨김
// 홈 화면에서 모든 일정 확인 가능 + 마감 일정 알림 배너 확인 가능
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'calendar_widget.dart';
import 'natural_input_page.dart';
import 'pages/filter_page.dart';
import 'pages/todo_test_page.dart';
import 'pages/profile_page.dart';
import 'utils/theme.dart'; // theme.dart import

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Stream<User?> authStateStream = FirebaseAuth.instance
      .authStateChanges();
  bool _navigatedToLogin = false;

  DateTime _selectedDate = DateTime.now();
  int _selectedBottomIndex = 0;

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    _initLocalNotifications();
    _scheduleAllDeadlineNotifications();
  }

  void _initLocalNotifications() {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse response) async {},
    );
  }

  Future<void> _scheduleDeadlineNotification({
    required int id,
    required String title,
    required DateTime scheduledDateTime,
  }) async {
    final tzDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);
    if (tzDateTime.isAfter(tz.TZDateTime.now(tz.local))) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        '마감 임박 일정',
        title,
        tzDateTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'deadline_channel',
            'Deadline Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'deadline_payload',
      );
    }
  }

  Future<void> _scheduleAllDeadlineNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('todos')
          .doc(user.uid)
          .collection('userTodos')
          .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      int notifId = 1;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final title = data['title'] as String? ?? '제목 없음';
        final endTimestamp = data['endDate'] as Timestamp?;
        final notifyOn = data['notification'] as bool? ?? true;
        if (endTimestamp == null || !notifyOn) continue;
        final endDate = endTimestamp.toDate().toLocal();
        await _scheduleDeadlineNotification(
          id: notifId++,
          title: title,
          scheduledDateTime: endDate,
        );
      }
    } catch (e) {
      debugPrint('예약 알림 등록 중 오류: $e');
    }
  }

  void _showTodayTodoPopup(List<String> todayTodoTitles) {
    if (todayTodoTitles.isEmpty) return;

    // 3개까진 전체 표시, 4개 이상이면 최대 3개 높이까지 보여주고 스크롤
    double maxHeight = todayTodoTitles.length > 3
        ? 3 * 60.0
        : todayTodoTitles.length * 60.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('오늘 마감 일정', style: TextStyle(color: Colors.black)),
        content: SizedBox(
          width: double.maxFinite,
          height: maxHeight,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: todayTodoTitles
                  .map(
                    (title) => ListTile(
                      leading: const Icon(
                        Icons.circle,
                        size: 10,
                        color: Colors.black,
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  String getDDayText(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);

    final diff = deadlineDate.difference(today).inDays;
    if (diff > 0) return 'D-${diff + 1}';
    if (diff == 0) return 'D-DAY';
    return 'D+${-diff}';
  }

  Color _subjectColor(String subject) {
    final hash = subject.hashCode;
    final hue = (hash % 360).toDouble();
    final Color base = HSLColor.fromAHSL(1.0, hue, 0.6, 0.6).toColor();
    final Color toned = Color.lerp(base, Colors.white, 0.25)!;
    return toned.withOpacity(0.95);
  }

  Widget _buildBody(User user) {
    switch (_selectedBottomIndex) {
      case 0:
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // ✅ 오늘 일정 요약 배너 (알림 ON일 때만 표시)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return Container();

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  final isNotificationOn = userData?['notificationOn'] ?? true;

                  if (!isNotificationOn) {
                    // 🔕 전체 알림 OFF 시 배너 표시 안 함
                    return const SizedBox.shrink();
                  }

                  // 🔔 알림 ON 상태일 때만 일정 확인
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('todos')
                        .doc(user.uid)
                        .collection('userTodos')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Container();

                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);

                      int count = 0;
                      List<String> titles = [];

                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final startTimestamp = data['startDate'] as Timestamp?;
                        final endTimestamp = data['endDate'] as Timestamp?;
                        final notifyOn = data['notification'] as bool? ?? true;

                        if (!notifyOn ||
                            startTimestamp == null ||
                            endTimestamp == null)
                          continue;

                        final startDate = startTimestamp.toDate();
                        final endDate = endTimestamp.toDate();

                        // ✅ 오늘이 startDate~endDate 사이에 포함되는 경우
                        if (!today.isBefore(
                              DateTime(
                                startDate.year,
                                startDate.month,
                                startDate.day,
                              ),
                            ) &&
                            !today.isAfter(
                              DateTime(
                                endDate.year,
                                endDate.month,
                                endDate.day,
                              ),
                            )) {
                          count++;
                          titles.add(data['title'] ?? '제목 없음');
                        }
                      }

                      if (count == 0) return const SizedBox.shrink();

                      return Card(
                        elevation: 3,
                        color: Colors.red[300], // 중간 빨강
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showTodayTodoPopup(titles),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  '오늘 마감 일정 있어요!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.notifications_active,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  color: AppColors.white,
                  child: CalendarWidget(
                    initialSelectedDate: _selectedDate,
                    onDateSelected: (selectedDate) =>
                        setState(() => _selectedDate = selectedDate),
                    isHome: true,
                  ),
                ),
              ),
            ],
          ),
        );
      case 1:
        return NaturalInputPage(
          selectedDate: _selectedDate,
          onDateSelected: (date) => setState(() => _selectedDate = date),
        );
      case 2:
        return const TodoTestPage();
      case 3:
        return const ProfilePage();
      default:
        return Container();
    }
  }

  void _showEditRestrictionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('일정 수정/삭제는 일정 화면에 일정 카드 클릭 시 가능합니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          if (!_navigatedToLogin) {
            _navigatedToLogin = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pushReplacementNamed(context, '/login'),
            );
          }
          return const Scaffold(body: Center(child: Text('로그인 화면으로 이동 중...')));
        }

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            actions: [
              IconButton(
                icon: Image.asset(
                  'assets/images/filter.png',
                  width: 16,
                  height: 18,
                ),
                tooltip: '일정 필터',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FilterPage()),
                ),
              ),
            ],
          ),
          body: GestureDetector(
            onTap: _showEditRestrictionMessage,
            child: _buildBody(user),
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.white,
            selectedItemColor: AppColors.darkBrown,
            unselectedItemColor: AppColors.gray2,
            currentIndex: _selectedBottomIndex,
            onTap: (index) => setState(() => _selectedBottomIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
              BottomNavigationBarItem(icon: Icon(Icons.add), label: '추가'),
              BottomNavigationBarItem(icon: Icon(Icons.list), label: '일정'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
            ],
          ),
        );
      },
    );
  }
}
