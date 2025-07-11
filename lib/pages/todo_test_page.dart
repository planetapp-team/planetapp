//일정 추가, 일정 목록, 일정 수정, 일정 삭제
// Firestore에 일정 데이터를 추가하고 목록을 실시간으로 불러오는 테스트 UI 화면
// lib/todo_test_page.dart

// 일정 추가, 목록 출력, 수정, 삭제 UI 테스트 화면
// lib/todo_test_page.dart

import 'package:flutter/material.dart';
import '../services/todo_service.dart';

class TodoTestPage extends StatefulWidget {
  const TodoTestPage({super.key});

  @override
  State<TodoTestPage> createState() => _TodoTestPageState();
}

class _TodoTestPageState extends State<TodoTestPage> {
  final titleController = TextEditingController();
  final subjectController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore 테스트')),
      body: Column(
        children: [
          // ✅ 일정 추가 입력 폼
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '할 일 제목'),
                ),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: '과목 입력'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final subject = subjectController.text.trim();

                    if (title.isNotEmpty && subject.isNotEmpty) {
                      TodoService.addTodo(
                        title,
                        subject,
                        DateTime.now().add(const Duration(days: 1)),
                      );
                      titleController.clear();
                      subjectController.clear();
                    }
                  },
                  child: const Text('일정 추가'),
                ),
              ],
            ),
          ),

          const Divider(),

          // ✅ 실시간 일정 목록
          Expanded(
            child: StreamBuilder(
              stream: TodoService.getTodoStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('에러 발생: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('등록된 일정이 없습니다.'));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final todo = doc.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(todo['title'] ?? ''),
                      subtitle: Text(
                        '과목: ${todo['subject'] ?? ''} / 카테고리: ${todo['category'] ?? ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              showEditDialog(context, doc.id, todo);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await TodoService.deleteTodo(doc.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ 수정 팝업
  Future<void> showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> currentData,
  ) async {
    final titleController = TextEditingController(text: currentData['title']);
    final subjectController = TextEditingController(
      text: currentData['subject'],
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('할 일 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(labelText: '과목'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final updatedTitle = titleController.text.trim();
                final updatedSubject = subjectController.text.trim();

                if (updatedTitle.isNotEmpty && updatedSubject.isNotEmpty) {
                  await TodoService.updateTodo(docId, {
                    'title': updatedTitle,
                    'subject': updatedSubject,
                  });
                }

                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }
}
