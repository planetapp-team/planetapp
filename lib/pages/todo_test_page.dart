// lib/todo_test_page.dart
// 할일관리 페이지 - Firestore에서 일정 목록을 실시간으로 불러와 보여주고,
// 일정 수정 및 삭제가 가능한 테스트용 UI 화면 구현
// 저장된 일정은 제목, 시작일, 마감일, 과목, 카테고리를 표시
// 각 일정 항목을 클릭하거나 수정/삭제 버튼으로 수정 가능

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore DB
import 'package:firebase_auth/firebase_auth.dart'; // Firebase 인증
import 'package:intl/intl.dart'; // 날짜 포맷팅
import 'package:planetapp/services/todo_service.dart'; // 할일 데이터 서비스

class TodoTestPage extends StatefulWidget {
  const TodoTestPage({super.key});

  @override
  State<TodoTestPage> createState() => _TodoTestPageState();
}

class _TodoTestPageState extends State<TodoTestPage> {
  late String userId; // 현재 로그인한 사용자 ID 저장 변수

  @override
  void initState() {
    super.initState();
    // 로그인한 사용자의 UID를 가져와 저장
    userId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('할일 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              // 로그아웃 처리
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // 로그아웃 알림 표시 후 로그인 화면으로 이동
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
            // 제목 텍스트
            const Text(
              '저장된 일정 목록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              // Firestore에서 userTodos 컬렉션의 문서들을 실시간 스트림으로 읽기
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('todos')
                    .doc(userId)
                    .collection('userTodos')
                    .orderBy('startDate') // 시작일 기준 오름차순 정렬
                    .snapshots(),
                builder: (context, snapshot) {
                  // 데이터가 아직 로딩 중이면 로딩 표시
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 데이터가 없거나 빈 리스트면 안내 메시지 출력
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('저장된 일정이 없습니다.'));
                  }

                  final docs = snapshot.data!.docs; // 전체 일정 문서 리스트

                  // 오늘 날짜 생성 (시/분/초 제외한 순수 날짜)
                  final today = DateTime.now();
                  final todayOnly = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );

                  // 일정 분류용 리스트 초기화
                  final List<DocumentSnapshot> todayList = [];
                  final List<DocumentSnapshot> upcomingList = [];
                  final List<DocumentSnapshot> pastList = [];

                  // 모든 일정 문서를 순회하며 분류 처리
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    // 시작일과 마감일 필드 가져오기 (Timestamp 형식)
                    final Timestamp? startTimestamp = data['startDate'];
                    final Timestamp? endTimestamp = data['endDate'];

                    // 시작일 또는 마감일이 없으면 건너뜀
                    if (startTimestamp == null || endTimestamp == null)
                      continue;

                    // Timestamp를 DateTime으로 변환
                    final startDate = startTimestamp.toDate();
                    final endDate = endTimestamp.toDate();

                    // 시/분/초 정보를 제외하고 날짜만 추출
                    final onlyStart = DateTime(
                      startDate.year,
                      startDate.month,
                      startDate.day,
                    );
                    final onlyEnd = DateTime(
                      endDate.year,
                      endDate.month,
                      endDate.day,
                    );

                    // 분류 기준:
                    if (onlyEnd.isBefore(todayOnly)) {
                      // 1. 마감일이 오늘 이전 → 지난 일정
                      pastList.add(doc);
                    } else if ((onlyStart.isBefore(todayOnly) ||
                            onlyStart.isAtSameMomentAs(todayOnly)) &&
                        (onlyEnd.isAfter(todayOnly) ||
                            onlyEnd.isAtSameMomentAs(todayOnly))) {
                      // 2. 오늘이 시작일과 마감일 사이 → 오늘 일정
                      todayList.add(doc);
                    } else if (onlyStart.isAfter(todayOnly)) {
                      // 3. 시작일이 오늘 이후 → 다가올 일정
                      upcomingList.add(doc);
                    } else {
                      // 기타 상황 (예외적으로 오늘 일정에 포함)
                      todayList.add(doc);
                    }
                  }

                  // 분류된 리스트를 섹션별로 구분하여 ListView로 출력
                  return ListView(
                    children: [
                      if (todayList.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '📌 오늘 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...todayList.map((doc) => _buildTodoItem(doc)),

                      if (upcomingList.isNotEmpty) const SizedBox(height: 12),
                      if (upcomingList.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '📅 다가올 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...upcomingList.map((doc) => _buildTodoItem(doc)),

                      if (pastList.isNotEmpty) const SizedBox(height: 12),
                      if (pastList.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '⏳ 지난 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...pastList.map((doc) => _buildTodoItem(doc)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 일정 하나를 보여주는 ListTile 위젯 생성 함수
  Widget _buildTodoItem(DocumentSnapshot doc) {
    final todo = doc.data() as Map<String, dynamic>;

    // 각 필드 가져오기 (null 대비 기본값 처리)
    final title = todo['title'] ?? '';
    final subject = todo['subject'] ?? '';
    final category = todo['category'] ?? '';
    final startDate = _formatDate(todo['startDate']);
    final endDate = _formatDate(todo['endDate']);

    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시작일: $startDate'),
          Text('마감일: $endDate'),
          Text('과목: $subject'),
          Text('카테고리: $category'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 수정 버튼
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              _showEditDialog(context, doc.id, todo);
            },
          ),
          // 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              await _deleteTodo(doc.id);
            },
          ),
        ],
      ),
      // 아이템 클릭 시에도 수정 다이얼로그 띄우기
      onTap: () {
        _showEditDialog(context, doc.id, todo);
      },
    );
  }

  // Firestore Timestamp 타입 날짜를 'yyyy-MM-dd' 문자열로 변환하는 헬퍼 함수
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
    // 수정 폼 텍스트 컨트롤러 초기화
    final titleController = TextEditingController(text: currentData['title']);
    final subjectController = TextEditingController(
      text: currentData['subject'],
    );
    String selectedCategory = currentData['category'] ?? '기타';

    // 시작일과 마감일 초기화 (Firestore Timestamp → DateTime)
    DateTime startDate = currentData['startDate']?.toDate() ?? DateTime.now();
    DateTime endDate = currentData['endDate']?.toDate() ?? DateTime.now();

    // 카테고리 선택지
    final List<String> categoryOptions = ['시험', '과제', '팀플', '기타'];

    // 다이얼로그를 StatefulBuilder로 표시하여 내부 상태 변경 가능
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
                    // 카테고리 드롭다운
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
                // 취소 버튼
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                // 저장 버튼
                TextButton(
                  onPressed: () async {
                    final updatedTitle = titleController.text.trim();
                    final updatedSubject = subjectController.text.trim();
                    final updatedCategory = selectedCategory;

                    // 빈값 없으면 업데이트 실행
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

  // 날짜 선택 다이얼로그 함수
  Future<DateTime?> _selectDate(DateTime initialDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    return picked;
  }

  // 일정 삭제 함수 (Firestore 문서 삭제 + 스낵바 알림)
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
