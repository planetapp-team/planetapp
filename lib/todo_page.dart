// lib/todo_page.dart
// 할 일 목록 화면 UI 및 Firestore에 할 일 저장 기능 구현

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _controller = TextEditingController();

  // 할 일 추가 함수
  Future<void> _addTodo() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return; // 입력이 비어있으면 처리하지 않음

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // 로그인하지 않은 상태면 저장 불가 안내
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    try {
      // Firestore 'todos' 컬렉션에 새로운 할 일 문서 추가
      final docRef = await FirebaseFirestore.instance.collection('todos').add({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(), // 서버 현재 시간 저장
        'uid': user.uid, // 사용자 ID 저장 (본인 할 일만 조회용)
      });

      // 저장 직후 문서 내용 가져와서 로그 출력 (디버깅용)
      final saved = await docRef.get();
      print('✅ 저장 완료: ${saved.data()}');

      _controller.clear(); // 입력 필드 초기화
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('할 일이 저장되었습니다!')));
    } catch (e) {
      // 저장 실패 시 에러 출력 및 사용자에게 안내
      print('❌ Firestore 저장 실패: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류 발생: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('할 일 목록')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 할 일 입력 필드
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: '할 일 입력'),
            ),
            const SizedBox(height: 10),

            // 저장 버튼
            ElevatedButton(onPressed: _addTodo, child: const Text('저장')),
            const SizedBox(height: 20),

            // 할 일 목록 표시 영역
            Expanded(
              child: user == null
                  // 로그인 안된 상태면 안내 문구 표시
                  ? const Center(child: Text('로그인 후 할 일을 확인하세요.'))
                  // 로그인 상태면 Firestore에서 실시간 할 일 목록 스트림 구독
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('todos')
                          .where('uid', isEqualTo: user.uid) // 본인 할 일만 조회
                          .orderBy('createdAt', descending: true) // 최신순 정렬
                          .snapshots(),
                      builder: (context, snapshot) {
                        // 로딩 중일 때 로딩 인디케이터 표시
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        // 에러 발생 시 에러 메시지 표시
                        if (snapshot.hasError) {
                          return Center(child: Text('에러: ${snapshot.error}'));
                        }
                        // 데이터 없으면 안내 문구 표시
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('등록된 할 일이 없습니다.'));
                        }

                        final docs = snapshot.data!.docs;

                        // 할 일 리스트를 ListView로 표시
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;

                            final text = data['text'] ?? '내용 없음';
                            final createdAt = data['createdAt'] as Timestamp?;
                            final dateStr = createdAt != null
                                ? createdAt.toDate().toString()
                                : '시간 정보 없음';

                            return ListTile(
                              title: Text(text),
                              subtitle: Text(dateStr),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
