//기능 :
// 로그인 상태 감지
// 비로그인 시 자도 이동
// Firebase에서 닉네임 불러오기
// 닉네임 없을 시 이메일 표시
// 로그아웃 처리
// 프로필 / 할일 관리 이동
// 자연어 입력 추가

// home_page.dart
// ✅ Firestore에서 닉네임 불러오기
// ✅ FirebaseAuth 로그인 상태 감지
// ✅ 로그인 안 된 경우 자동으로 로그인 화면 이동
// ✅ 로그아웃 처리 및 할일 관리 화면 이동 버튼 포함

//필터 페이지 이동 버튼 추가
// home_page.dart

// home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'calendar_widget.dart';
import 'natural_input_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Stream<User?> authStateStream = FirebaseAuth.instance
      .authStateChanges();
  bool _navigatedToLogin = false;

  DateTime? _selectedDate;

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

            if (!userDocSnapshot.hasData || !userDocSnapshot.data!.exists) {
              return _buildHomeScaffold(user.email ?? '사용자', user.uid);
            }

            final data = userDocSnapshot.data!.data();
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

  Scaffold _buildHomeScaffold(String displayName, String userId) {
    return Scaffold(
      appBar: AppBar(
        title: Text('홈 - 환영합니다, $displayName 님'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '프로필',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('로그아웃 되었습니다')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            flex: 3,
            child: CalendarWidget(
              onDateSelected: (selectedDate) {
                setState(() {
                  _selectedDate = selectedDate;
                });
              },
            ),
          ),
          const Divider(),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('자연어 일정 추가'),
                    onPressed: () {
                      if (_selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('먼저 날짜를 선택하세요')),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NaturalInputPage(selectedDate: _selectedDate!),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.list),
                    label: const Text('할일 관리'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/todo_test');
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('필터 보기'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/filter');
                    },
                  ),
                  const SizedBox(height: 20),

                  // 선택한 날짜 일정 목록 보여주기
                  if (_selectedDate != null)
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('todos')
                            .doc(userId)
                            .collection('userTodos')
                            .where(
                              'date',
                              isEqualTo: Timestamp.fromDate(
                                DateTime(
                                  _selectedDate!.year,
                                  _selectedDate!.month,
                                  _selectedDate!.day,
                                ),
                              ),
                            )
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text('선택한 날짜에 일정이 없습니다.'),
                            );
                          }

                          final todos = snapshot.data!.docs;

                          return ListView.separated(
                            itemCount: todos.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final todo = todos[index].data();
                              return ListTile(
                                title: Text(todo['title'] ?? ''),
                                subtitle: Text(
                                  '${todo['subject'] ?? ''} / ${todo['category'] ?? ''}',
                                ),
                              );
                            },
                          );
                        },
                      ),
                    )
                  else
                    const Text('캘린더에서 날짜를 선택하면 일정이 여기에 표시됩니다.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
