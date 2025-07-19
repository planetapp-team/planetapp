// home_page.dart
// 홈 화면: 로그인 상태 확인 → 사용자 정보 불러오기 → 자연어 일정 추가, 할일 관리, 필터 버튼 + 캘린더 + 오늘 일정 리스트

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'calendar_widget.dart'; // 캘린더 위젯 (선택 날짜 전달)
import 'natural_input_page.dart'; // 자연어 일정 추가 페이지
import 'pages/filter_page.dart'; // 필터 설정 페이지
import 'pages/todo_test_page.dart'; // 할일 관리 페이지

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Stream<User?> authStateStream = FirebaseAuth.instance
      .authStateChanges(); // 로그인 상태 스트림
  bool _navigatedToLogin = false; // 로그인 페이지 중복 이동 방지 플래그

  DateTime _selectedDate = DateTime.now(); // 선택된 날짜
  List<Map<String, dynamic>> todayTodos = []; // 선택된 날짜의 일정 리스트

  @override
  void initState() {
    super.initState();
    _loadTodayTodos(); // 최초 시작 시 오늘 일정 불러오기
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // FirebaseAuth의 상태가 아직 확인되지 않은 경우 로딩 화면
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 로그인되지 않은 경우 → 로그인 화면으로 이동
        if (user == null) {
          if (!_navigatedToLogin) {
            _navigatedToLogin = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/login');
            });
          }
          return const Scaffold(body: Center(child: Text('로그인 화면으로 이동 중...')));
        }

        // 로그인된 유저의 Firestore 사용자 정보 불러오기 (닉네임 포함)
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

            // 본격적인 홈 화면 UI 시작
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
                    // ✅ 상단 버튼 3개: 자연어 일정 추가, 할일 관리, 필터 보기
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 자연어 일정 추가 버튼
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

                        // 할일 관리 버튼
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

                        // 필터 보기 버튼
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

                    // ✅ 캘린더 위젯
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

                    // ✅ 선택된 날짜 텍스트 표시
                    Text(
                      '선택된 날짜: ${_selectedDate.toLocal().toIso8601String().substring(0, 10)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    // ✅ 오늘 일정 리스트
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

  /// Firestore에서 선택된 날짜가 포함된 일정 불러오기
  void _loadTodayTodos() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 선택 날짜의 시작과 끝 범위
    final selectedDateStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final selectedDateEnd = selectedDateStart.add(const Duration(days: 1));

    // Firestore에서 사용자 일정 불러오기
    FirebaseFirestore.instance
        .collection('todos')
        .where('userId', isEqualTo: user.uid)
        .get()
        .then((querySnapshot) {
          // 선택 날짜가 시작일과 마감일 사이에 있는 일정 필터링
          final filtered = querySnapshot.docs.map((doc) => doc.data()).where((
            todo,
          ) {
            final start = (todo['startDate'] as Timestamp).toDate();
            final due = (todo['due_date'] as Timestamp).toDate();
            return !(_selectedDate.isBefore(start) ||
                _selectedDate.isAfter(due));
          }).toList();

          // 시작일 기준 정렬
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

  /// 선택된 날짜의 일정 리스트 UI
  Widget _buildTodayTodoList() {
    if (todayTodos.isEmpty) {
      return const Center(child: Text('선택된 날짜에 일정이 없습니다.'));
    }

    return ListView.builder(
      itemCount: todayTodos.length,
      itemBuilder: (context, index) {
        final todo = todayTodos[index];

        // 날짜 형식 포맷 함수
        String formatDate(dynamic timestamp) {
          if (timestamp == null) return '없음';
          if (timestamp is Timestamp) {
            final dt = timestamp.toDate();
            return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
          }
          return '형식오류';
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(todo['title'] ?? '제목 없음'),

            // 일정 정보 상세 (과목, 카테고리, 날짜)
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '과목: ${todo['subject'] ?? '-'} / 카테고리: ${todo['category'] ?? '-'}',
                ),
                Text('시작일: ${formatDate(todo['startDate'])}'),
                Text('마감일: ${formatDate(todo['due_date'])}'),
              ],
            ),

            // 삭제 버튼
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () {
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
                        _loadTodayTodos(); // 삭제 후 다시 불러오기
                      });
                }
              },
            ),

            // 클릭 시 할일 페이지 이동
            onTap: () {
              Navigator.pushNamed(context, '/todo_test');
            },
          ),
        );
      },
    );
  }
}
