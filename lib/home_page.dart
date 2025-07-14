//home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'calendar_widget.dart';
import 'natural_input_page.dart';
import 'pages/filter_page.dart'; // 필터 페이지 import
import 'pages/todo_test_page.dart'; // 할일 관리 페이지 import

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
  List<Map<String, dynamic>> todayTodos = [];

  @override
  void initState() {
    super.initState();
    _loadTodayTodos(); // 초기 로드 (오늘 일정)
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
              body: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 상단 버튼 3개: 자연어 일정 추가, 할일 관리, 필터 보기
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

                    // 캘린더 위젯
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

                    // 선택된 날짜 텍스트
                    Text(
                      '선택된 날짜: ${_selectedDate.toLocal().toIso8601String().substring(0, 10)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // 오늘 일정 리스트
                    Expanded(flex: 4, child: _buildTodayTodoList()),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Firestore에서 선택된 날짜 일정 불러오기
  void _loadTodayTodos() {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    FirebaseFirestore.instance
        .collection('todos')
        .where('startDate', isGreaterThanOrEqualTo: startOfDay)
        .where('startDate', isLessThan: endOfDay)
        .get()
        .then((querySnapshot) {
          setState(() {
            todayTodos = querySnapshot.docs.map((doc) => doc.data()).toList();
          });
        });
  }

  // 오늘 일정 리스트 UI
  Widget _buildTodayTodoList() {
    if (todayTodos.isEmpty) {
      return const Center(child: Text('선택된 날짜에 일정이 없습니다.'));
    }
    return ListView.builder(
      itemCount: todayTodos.length,
      itemBuilder: (context, index) {
        final todo = todayTodos[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(todo['title'] ?? '제목 없음'),
            subtitle: Text(
              '과목: ${todo['subject'] ?? '-'} / 카테고리: ${todo['category'] ?? '-'}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
                // 삭제 기능 예: Firestore 문서 삭제
                final docId = todo['id'];
                if (docId != null) {
                  FirebaseFirestore.instance
                      .collection('todos')
                      .doc(docId)
                      .delete()
                      .then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('일정이 삭제되었습니다')),
                        );
                        _loadTodayTodos();
                      });
                }
              },
            ),
            onTap: () {
              // 할일 관리 페이지로 이동
              Navigator.pushNamed(context, '/todo_test');
            },
          ),
        );
      },
    );
  }
}
