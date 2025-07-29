// home_page.dart
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

  // 오늘 날짜 포함 일정 (간략 리스트)
  List<Map<String, dynamic>> todayTodos = [];

  // 알림 예약된 일정 (상세 리스트)
  List<Map<String, dynamic>> notificationTodos = [];

  // 오늘 마감 일정 배너 노출 여부
  bool _showDeadlineBanner = false;

  @override
  void initState() {
    super.initState();

    tzdata.initializeTimeZones();
    _initLocalNotifications();

    _loadTodayTodos();
    _loadNotificationTodos();

    _checkTodayDeadlinesAndNotify();
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
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          // 필요 시 알림 클릭 동작 구현 가능
        }
      },
    );
  }

  Future<void> _checkTodayDeadlinesAndNotify() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    final startOfDayLocal = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDayLocal = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final startOfDayUTC = startOfDayLocal.toUtc();
    final endOfDayUTC = endOfDayLocal.toUtc();

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('todos')
          .doc(user.uid)
          .collection('userTodos')
          .where(
            'endDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDayUTC),
          )
          .where(
            'endDate',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDayUTC),
          )
          .get();

      if (querySnapshot.docs.isEmpty) return;

      List<String> titles = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['title'] != null) {
          titles.add(data['title']);
        }
      }
      if (titles.isEmpty) return;

      await flutterLocalNotificationsPlugin.show(
        0,
        '오늘 마감 일정이 있어요!',
        titles.join(', '),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'deadline_channel',
            'Deadline Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'deadline_payload',
      );

      if (mounted) {
        setState(() {
          _showDeadlineBanner = true;
        });
      }
    } catch (e) {
      debugPrint('로컬 알림 오류: $e');
    }
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

        if (endTimestamp == null) continue;

        final endDate = endTimestamp.toDate();

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

  /// 선택된 날짜 포함 일정 (간략 리스트)
  void _loadTodayTodos() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('todos')
        .doc(user.uid)
        .collection('userTodos')
        .get()
        .then((querySnapshot) {
          final filtered = querySnapshot.docs
              .map((doc) {
                final data = doc.data();
                return {'id': doc.id, ...data};
              })
              .where((todo) {
                final startTimestamp = todo['startDate'];
                final endTimestamp = todo['endDate'];

                if (startTimestamp == null || endTimestamp == null)
                  return false;

                final start = (startTimestamp as Timestamp).toDate();
                final due = (endTimestamp as Timestamp).toDate();

                return !(_selectedDate.isBefore(start) ||
                    _selectedDate.isAfter(due));
              })
              .toList();

          filtered.sort((a, b) {
            final aStart = (a['startDate'] as Timestamp).toDate();
            final bStart = (b['startDate'] as Timestamp).toDate();
            return aStart.compareTo(bStart);
          });

          setState(() {
            todayTodos = filtered;
          });
        });
  }

  /// 알림 예약된 일정 (상세 리스트)
  void _loadNotificationTodos() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    FirebaseFirestore.instance
        .collection('todos')
        .doc(user.uid)
        .collection('userTodos')
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .get()
        .then((querySnapshot) {
          final filtered = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();

          filtered.sort((a, b) {
            final aStart = (a['startDate'] as Timestamp).toDate();
            final bStart = (b['startDate'] as Timestamp).toDate();
            return aStart.compareTo(bStart);
          });

          setState(() {
            notificationTodos = filtered;
          });
        });
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/login');
            });
          }
          return const Scaffold(body: Center(child: Text('로그인 화면으로 이동 중...')));
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = userDocSnapshot.data?.data();
            final nickname = data?['nickname'] as String?;
            final displayName = (nickname != null && nickname.trim().isNotEmpty)
                ? nickname
                : (user.email ?? '사용자');

            return Scaffold(
              appBar: AppBar(
                title: Text('홈 - 환영합니다, $displayName 님'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person),
                    tooltip: '프로필',
                    onPressed: () => Navigator.pushNamed(context, '/profile'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: '로그아웃',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그아웃 되었습니다')),
                        );
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (_showDeadlineBanner)
                    MaterialBanner(
                      //확인용 :마감 일정 알림 배너 띄우기
                      //-> 일정확인 클릭시 할일관리 이동, x 클릭시 사라짐
                      content: const Text('오늘 마감 일정이 있습니다.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/todo_test');
                          },
                          child: const Text(
                            '일정 확인',
                            style: TextStyle(
                              color: Color.fromARGB(255, 51, 156, 232),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showDeadlineBanner = false;
                            });
                          },
                        ),
                      ],
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 상단 버튼 3개
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit_note, size: 16),
                                label: const Text(
                                  '자연어 일정 추가',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NaturalInputPage(
                                        selectedDate: _selectedDate,
                                        onDateSelected: (date) {
                                          setState(() {
                                            _selectedDate = date;
                                            _loadTodayTodos();
                                          });
                                        },
                                      ),
                                    ),
                                  ).then((refresh) {
                                    if (refresh == true)
                                      setState(() => _loadTodayTodos());
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.list, size: 16),
                                label: const Text(
                                  '할일 관리',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/todo_test'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.filter_alt, size: 16),
                                label: const Text(
                                  '필터 보기',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/filter'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 캘린더
                          Expanded(
                            flex: 6,
                            child: CalendarWidget(
                              initialSelectedDate: _selectedDate,
                              onDateSelected: (selectedDate) {
                                setState(() {
                                  _selectedDate = selectedDate;
                                  _loadTodayTodos();
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 캘린더 바로 아래 일정 리스트 삭제

                          // 선택된 날짜 텍스트
                          Text(
                            '다가오는 마감일 일정 리스트 : ${"선택한 날짜 " + _selectedDate.toLocal().toIso8601String().substring(0, 10) + " 입니다."}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          // 알림 예약된 상세 일정 리스트 (그 아래)
                          Expanded(
                            flex: 4,
                            child: _buildNotificationTodoList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 간략한 오늘 일정 리스트 (제목, 카테고리/과목만 보여줌)
  Widget _buildSimpleTodayTodoList() {
    if (todayTodos.isEmpty) {
      return const Center(child: Text('아래에서 다가오는 마감일 일정을 확인하세요!'));
    }

    return ListView.builder(
      itemCount: todayTodos.length,
      itemBuilder: (context, index) {
        final todo = todayTodos[index];

        return ListTile(
          title: Text(todo['title'] ?? '제목 없음'),
          subtitle: Text(
            '${todo['category'] ?? '-'} / ${todo['subject'] ?? '-'}',
          ),
          onTap: () {
            Navigator.pushNamed(context, '/todo_test');
          },
        );
      },
    );
  }

  // 알림 예약된 상세 일정 리스트 (시작일, 마감일, 제목, 과목, 카테고리 포함)
  Widget _buildNotificationTodoList() {
    if (notificationTodos.isEmpty) {
      return const Center(child: Text('예약된 알림 일정이 없습니다.'));
    }

    String formatDate(dynamic timestamp) {
      if (timestamp == null) return '없음';
      if (timestamp is Timestamp) {
        final dt = timestamp.toDate();
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }
      return '형식오류';
    }

    final user = FirebaseAuth.instance.currentUser;

    return ListView.builder(
      itemCount: notificationTodos.length,
      itemBuilder: (context, index) {
        final todo = notificationTodos[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(todo['title'] ?? '제목 없음'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '과목: ${todo['subject'] ?? '-'} / 카테고리: ${todo['category'] ?? '-'}',
                ),
                Text('시작일: ${formatDate(todo['startDate'])}'),
                Text('마감일: ${formatDate(todo['endDate'])}'),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                final docId = todo['id'];
                if (docId != null && user != null) {
                  FirebaseFirestore.instance
                      .collection('todos')
                      .doc(user.uid)
                      .collection('userTodos')
                      .doc(docId)
                      .delete()
                      .then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('일정이 삭제되었습니다')),
                        );
                        _loadNotificationTodos();
                        _loadTodayTodos();
                      });
                }
              },
            ),
            onTap: () {
              Navigator.pushNamed(context, '/todo_test');
            },
          ),
        );
      },
    );
  }
}
