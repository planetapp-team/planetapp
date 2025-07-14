// lib/todo_test_page.dart
// 할일관리 페이지 - Firestore에서 일정 목록을 실시간으로 불러와 보여주고,
// 일정 수정 및 삭제가 가능한 테스트용 UI 화면 구현
// 저장된 일정은 제목, 시작일, 마감일, 과목, 카테고리를 표시
// 각 일정 항목을 클릭하거나 수정/삭제 버튼으로 수정 가능

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // 날짜 형식 변환용
import 'package:planetapp/services/todo_service.dart'; // 일정 관련 서비스

class TodoTestPage extends StatefulWidget {
  const TodoTestPage({super.key});

  @override
  State<TodoTestPage> createState() => _TodoTestPageState();
}

class _TodoTestPageState extends State<TodoTestPage> {
  late String userId;

  @override
  void initState() {
    super.initState();
    // 현재 로그인한 사용자의 UID 저장
    userId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('할일 관리'),
        actions: [
          // 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              // Firebase 인증에서 로그아웃 처리
              await FirebaseAuth.instance.signOut();

              // 로그아웃 후 사용자에게 안내 메시지 띄우고 로그인 화면으로 이동
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
            // 저장된 전체 일정 제목 표시
            const Text(
              '저장된 일정 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              // Firestore에서 해당 사용자의 모든 일정 문서를 실시간 스트림으로 불러오기
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('todos')
                    .doc(userId)
                    .collection('userTodos')
                    .snapshots(),
                builder: (context, snapshot) {
                  // 데이터 로딩 중일 때 로딩 인디케이터 표시
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 데이터 없거나 빈 리스트일 경우 메시지 표시
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('저장된 일정이 없습니다.'));
                  }

                  final docs = snapshot.data!.docs;

                  // 일정 목록을 리스트뷰로 표시
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final todo = doc.data() as Map<String, dynamic>;

                      // 일정의 각 필드 추출 (null 체크 및 기본값 처리)
                      final title = todo['title'] ?? '';
                      final subject = todo['subject'] ?? '';
                      final category = todo['category'] ?? '';
                      final startDate = _formatDate(todo['startDate']);
                      final endDate = _formatDate(todo['endDate']);

                      return ListTile(
                        // 일정 제목 표시
                        title: Text(title),

                        // 시작일, 마감일, 과목, 카테고리 정보를 서브타이틀에 세로로 나열
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('시작일: $startDate'),
                            Text('마감일: $endDate'),
                            Text('과목: $subject'),
                            Text('카테고리: $category'),
                          ],
                        ),

                        // 오른쪽에 수정/삭제 버튼 표시
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 수정 버튼 - 클릭 시 수정 다이얼로그 띄움
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                _showEditDialog(context, doc.id, todo);
                              },
                            ),
                            // 삭제 버튼 - 클릭 시 일정 삭제 처리
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _deleteTodo(doc.id);
                              },
                            ),
                          ],
                        ),

                        // 리스트 아이템 클릭 시에도 수정 다이얼로그 띄움
                        onTap: () {
                          _showEditDialog(context, doc.id, todo);
                        },
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

  // Firestore Timestamp 타입 날짜를 'yyyy-MM-dd' 형식 문자열로 변환
  String _formatDate(dynamic date) {
    if (date == null) return '없음';
    final formattedDate = DateFormat('yyyy-MM-dd').format(date.toDate());
    return formattedDate;
  }

  // 일정 수정 다이얼로그 표시 함수
  Future<void> _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> currentData,
  ) async {
    // 수정 폼의 텍스트 필드 컨트롤러 초기화
    final titleController = TextEditingController(text: currentData['title']);
    final subjectController = TextEditingController(
      text: currentData['subject'],
    );

    // 드롭다운 초기 선택값으로 현재 일정의 카테고리 설정, 기본 '기타'
    String selectedCategory = currentData['category'] ?? '기타';

    // 시작일과 마감일 초기화 (Firestore Timestamp를 DateTime으로 변환)
    DateTime startDate = currentData['startDate']?.toDate() ?? DateTime.now();
    DateTime endDate = currentData['endDate']?.toDate() ?? DateTime.now();

    // 카테고리 선택 옵션 리스트
    final List<String> categoryOptions = ['시험', '과제', '팀플', '기타'];

    // 다이얼로그 표시 (StatefulBuilder로 내부 상태 변경 가능)
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('할 일 수정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 제목 입력 필드
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: '제목'),
                    ),
                    // 과목 입력 필드
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: '과목'),
                    ),
                    // 카테고리 선택 드롭다운
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: '카테고리'),
                      value: selectedCategory,
                      items: categoryOptions.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                    // 시작일 선택 버튼
                    Row(
                      children: [
                        const Text('시작일: '),
                        TextButton(
                          onPressed: () async {
                            final picked = await _selectDate(startDate);
                            if (picked != null) {
                              setState(() {
                                startDate = picked;
                              });
                            }
                          },
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(startDate),
                          ),
                        ),
                      ],
                    ),
                    // 마감일 선택 버튼
                    Row(
                      children: [
                        const Text('마감일: '),
                        TextButton(
                          onPressed: () async {
                            final picked = await _selectDate(endDate);
                            if (picked != null) {
                              setState(() {
                                endDate = picked;
                              });
                            }
                          },
                          child: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                // 취소 버튼 - 다이얼로그 닫기
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                // 저장 버튼 - 입력값이 모두 있으면 TodoService.updateTodo 호출하여 업데이트 후 닫기
                TextButton(
                  onPressed: () async {
                    final updatedTitle = titleController.text.trim();
                    final updatedSubject = subjectController.text.trim();
                    final updatedCategory = selectedCategory;

                    if (updatedTitle.isNotEmpty &&
                        updatedSubject.isNotEmpty &&
                        updatedCategory.isNotEmpty) {
                      await TodoService.updateTodo(docId, {
                        'title': updatedTitle,
                        'subject': updatedSubject,
                        'category': updatedCategory,
                        'startDate': Timestamp.fromDate(startDate),
                        'endDate': Timestamp.fromDate(endDate),
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
      },
    );
  }

  // 날짜 선택 다이얼로그 표시 함수
  Future<DateTime?> _selectDate(DateTime initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020), // 선택 가능한 최소 날짜
      lastDate: DateTime(2100), // 선택 가능한 최대 날짜
    );
    return picked;
  }

  // 일정 삭제 함수 - Firestore에서 문서 삭제 후 삭제 완료 메시지 표시
  Future<void> _deleteTodo(String docId) async {
    final todoDoc = FirebaseFirestore.instance
        .collection('todos')
        .doc(userId)
        .collection('userTodos')
        .doc(docId);

    await todoDoc.delete();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
  }
}
