// 할 일 목록 화면 UI
// Firestore에 할 일 저장하는 코드

// lib/todo_page.dart
//할 일 목록 화면 + Firestore 저장 기본
// lib/todo_page.dart

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

  Future<void> _addTodo() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    try {
      final docRef = await FirebaseFirestore.instance.collection('todos').add({
        'text': text,
        'createdAt': FieldValue.serverTimestamp(), // 서버시간 저장
        'uid': user.uid,
      });

      // 저장 직후에 확인용 로그
      final saved = await docRef.get();
      print('✅ 저장 완료: ${saved.data()}');

      _controller.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('할 일이 저장되었습니다!')));
    } catch (e) {
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
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: '할 일 입력'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _addTodo, child: const Text('저장')),
            const SizedBox(height: 20),
            Expanded(
              child: user == null
                  ? const Center(child: Text('로그인 후 할 일을 확인하세요.'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('todos')
                          .where('uid', isEqualTo: user.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('에러: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('등록된 할 일이 없습니다.'));
                        }

                        final docs = snapshot.data!.docs;

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
