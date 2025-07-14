// home_page.dart
// 기능:
// - FirebaseAuth 로그인 상태 감지 및 자동 로그인 화면 이동 처리
// - Firestore에서 사용자 닉네임 실시간 로드 및 표시 (닉네임 없으면 이메일 표시)
// - 로그아웃 처리 및 알림 표시
// - 프로필, 할일 관리, 필터 페이지 이동 버튼 제공
// - 달력 위젯 표시 및 선택된 날짜에 해당하는 오늘 일정 조회 및 리스트 표시
// - 자연어 일정 추가 화면으로 이동

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
  // FirebaseAuth 인증 상태 스트림 구독
  final Stream<User?> authStateStream = FirebaseAuth.instance
      .authStateChanges();
  bool _navigatedToLogin = false; // 로그인 화면 이동 여부 중복 방지
  DateTime? _selectedDate; // 선택된 날짜
  List<Map<String, dynamic>> todayTodos = []; // 선택된 날짜(오늘)의 할일 목록

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // 인증 상태 로딩 중 표시
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 로그인 안 된 경우 로그인 화면으로 자동 이동
        if (user == null) {
          if (!_navigatedToLogin) {
            _navigatedToLogin = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/login');
            });
          }

          return const Scaffold(body: Center(child: Text('로그인 화면으로 이동 중...')));
        }

        // 로그인 된 경우 Firestore에서 사용자 닉네임 실시간 구독
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

            // Firestore에서 닉네임 불러오기, 없으면 이메일 표시
            final data = userDocSnapshot.data?.data();
            final nickname = data?['nickname'] as String?;
            final displayName = (nickname != null && nickname.trim().isNotEmpty)
                ? nickname
                : (user.email ?? '사용자');

            return _buildHomeScaffold(displayName, user.uid);
          },
        );
      },
    );
  }

  // 홈 화면 UI 구성
  Scaffold _buildHomeScaffold(String displayName, String userId) {
    return Scaffold(
      appBar: AppBar(
        title: Text('홈 - 환영합니다, $displayName 님'),
        actions: [
          // 프로필 페이지 이동 버튼
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '프로필',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('로그아웃 되었습니다')));
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
            // 자연어 일정 추가, 할일 관리, 필터 보기 버튼
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
                    if (_selectedDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('먼저 날짜를 선택하세요')),
                      );
                      return;
                    }

                    // 자연어 입력 페이지로 이동, 날짜 선택 콜백 포함
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NaturalInputPage(
                          selectedDate: _selectedDate!,
                          onDateSelected: (date) {
                            setState(() {
                              _selectedDate = date;
                            });
                          },
                        ),
                      ),
                    ).then((refresh) {
                      if (refresh == true) setState(() {}); // 리프레시 처리
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
                  label: const Text('할일 관리', style: TextStyle(fontSize: 12)),
                  onPressed: () => Navigator.pushNamed(context, '/todo_test'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.filter_alt, size: 16),
                  label: const Text('필터 보기', style: TextStyle(fontSize: 12)),
                  onPressed: () => Navigator.pushNamed(context, '/filter'),
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
            // 달력 위젯 표시 및 날짜 선택 시 오늘 일정 로드
            Expanded(
              child: CalendarWidget(
                onDateSelected: (selectedDate) {
                  setState(() {
                    _selectedDate = selectedDate;
                    _loadTodayTodos(); // 선택된 날짜에 따른 일정 로드
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedDate != null) ...[
              const SizedBox(height: 8),
              // 오늘 일정 리스트 표시
              Expanded(child: _buildTodayTodoList()),
            ],
          ],
        ),
      ),
    );
  }

  // 선택된 날짜의 오늘 일정을 Firestore에서 불러오는 함수
  void _loadTodayTodos() {
    final today = _selectedDate ?? DateTime.now();
    FirebaseFirestore.instance
        .collection('todos')
        // 선택된 날짜 0시 이후 일정
        .where('startDate', isGreaterThanOrEqualTo: today)
        // 선택된 날짜 24시 이전 일정
        .where(
          'startDate',
          isLessThanOrEqualTo: today.add(const Duration(days: 1)),
        )
        .get()
        .then((querySnapshot) {
          setState(() {
            // 쿼리 결과를 리스트에 저장
            todayTodos = querySnapshot.docs.map((doc) => doc.data()).toList();
          });
        });
  }

  // 오늘 일정 리스트를 표시하는 위젯 생성
  Widget _buildTodayTodoList() {
    if (todayTodos.isEmpty) {
      return const Center(child: Text('오늘 일정이 없습니다.'));
    }
    return ListView.builder(
      itemCount: todayTodos.length,
      itemBuilder: (context, index) {
        final todo = todayTodos[index];
        return ListTile(
          title: Text(todo['title']),
          subtitle: Text('과목: ${todo['subject']} / 카테고리: ${todo['category']}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: 일정 삭제 로직 추가 필요
            },
          ),
          onTap: () {
            // TODO: 일정 수정 화면으로 이동 (현재는 할일 관리 화면으로 이동)
            Navigator.pushNamed(context, '/todo_test');
          },
        );
      },
    );
  }
}
