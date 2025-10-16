// lib/todo_test_page.dart
// 일정 화면(=일정 관리 화면)
// 기존 기능, 구조 유지
// ✅ 일정 수정 팝업창에 메모 입력/수정 기능 추가
// ✅ 시작일/마감일 캘린더 & 시간 선택 버튼 검정색 + 선택된 날짜/시간 노란색 하이라이트 + 확인/취소 한글 표시
// ✅ D-Day 표시 단순화 적용 + 별표 아이콘 추가 (오른쪽 끝, 토글 가능)
// ✅ 지나간 일정 필터 드롭다운 추가 (1주일, 1개월, 2개월, 3개월, 전체) + 기본값 1주일
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:planetapp/services/todo_service.dart';
import '../services/fcm_service.dart';
import '../main.dart'; // flutterLocalNotificationsPlugin 가져오기
import '../utils/theme.dart'; // AppColors.yellow 사용

class TodoTestPage extends StatefulWidget {
  const TodoTestPage({super.key});

  @override
  State<TodoTestPage> createState() => _TodoTestPageState();
}

class _TodoTestPageState extends State<TodoTestPage> {
  late String userId;
  late FcmService _fcmService;

  // 지나간 일정 필터
  String pastFilter = '1주일';
  final List<String> pastFilterOptions = ['1주일', '1개월', '2개월', '3개월', '전체'];

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser!.uid;
    _fcmService = FcmService(
      flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일정 관리')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('todos')
                    .doc(userId)
                    .collection('userTodos')
                    .orderBy('startDate')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('저장된 일정이 없습니다.'));
                  }

                  final docs = snapshot.data!.docs;
                  final today = DateTime.now();
                  final todayOnly = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  );

                  final List<DocumentSnapshot> todayList = [];
                  final List<DocumentSnapshot> upcomingList = [];
                  final List<DocumentSnapshot> pastList = [];
                  final List<DocumentSnapshot> undeterminedList = [];

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? startTimestamp = data['startDate'];
                    final Timestamp? endTimestamp = data['endDate'];
                    final startDate = startTimestamp?.toDate();
                    final endDate = endTimestamp?.toDate();

                    if (endDate == null) {
                      undeterminedList.add(doc);
                      continue;
                    }

                    final onlyStart = startDate != null
                        ? DateTime(
                            startDate.year,
                            startDate.month,
                            startDate.day,
                          )
                        : null;
                    final onlyEnd = DateTime(
                      endDate.year,
                      endDate.month,
                      endDate.day,
                    );

                    if (onlyEnd.isBefore(todayOnly)) {
                      pastList.add(doc);
                    } else if ((onlyStart != null &&
                            (onlyStart.isBefore(todayOnly) ||
                                onlyStart.isAtSameMomentAs(todayOnly))) &&
                        (onlyEnd.isAfter(todayOnly) ||
                            onlyEnd.isAtSameMomentAs(todayOnly))) {
                      todayList.add(doc);
                    } else if (onlyStart != null &&
                        onlyStart.isAfter(todayOnly)) {
                      upcomingList.add(doc);
                    } else {
                      todayList.add(doc);
                    }
                  }

                  // 지나간 일정 필터 적용
                  final DateTime now = DateTime.now();
                  final filteredPastList = pastList.where((doc) {
                    if (pastFilter == '전체') return true;
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? endTs = data['endDate'];
                    if (endTs == null) return false;
                    final endDate = endTs.toDate();
                    Duration diff = now.difference(endDate);
                    switch (pastFilter) {
                      case '1주일':
                        return diff.inDays <= 7;
                      case '1개월':
                        return diff.inDays <= 30;
                      case '2개월':
                        return diff.inDays <= 60;
                      case '3개월':
                        return diff.inDays <= 90;
                      default:
                        return true;
                    }
                  }).toList();

                  return ListView(
                    children: [
                      if (todayList.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'D-day',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...todayList.map((doc) => _buildTodoItem(doc)),
                      ],
                      if (upcomingList.isNotEmpty) const SizedBox(height: 12),
                      if (upcomingList.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '예정된 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...upcomingList.map((doc) => _buildTodoItem(doc)),
                      if (pastList.isNotEmpty) const SizedBox(height: 12),
                      if (pastList.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '지나간 일정',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DropdownButton<String>(
                              value: pastFilter,
                              items: pastFilterOptions
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  pastFilter = value!;
                                });
                              },
                              dropdownColor: Colors.white, // ✅ 배경 흰색 고정
                            ),
                          ],
                        ),
                      ...filteredPastList.map((doc) => _buildTodoItem(doc)),
                      if (undeterminedList.isNotEmpty)
                        const SizedBox(height: 12),
                      if (undeterminedList.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '날짜 미정 일정',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ...undeterminedList.map((doc) => _buildTodoItem(doc)),
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

  Color getSubjectColor(String subject) {
    final hash = subject.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.75).toColor();
  }

  /// ✅ D-Day 계산 및 표시 (간단하게 텍스트 + 별표)
  Widget _buildDdayTag(Map<String, dynamic> todo) {
    final Timestamp? endTs = todo['endDate'];
    if (endTs == null) return const SizedBox.shrink();

    final DateTime endDate = endTs.toDate();
    final DateTime now = DateTime.now();
    final DateTime endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    final DateTime todayOnly = DateTime(now.year, now.month, now.day);

    final int diff = endOnly.difference(todayOnly).inDays;

    String text;
    if (diff == 0) {
      text = 'D-Day';
    } else if (diff > 0) {
      text = 'D-$diff';
    } else {
      text = '종료';
    }

    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildTodoItem(DocumentSnapshot doc) {
    final todo = doc.data() as Map<String, dynamic>;
    final title = todo['title'] ?? '';
    final subject = todo['subject'] ?? '';
    final bool completed = todo['completed'] ?? false;
    final bool favorite = todo['favorite'] ?? false; // 별표 상태
    final Color cardColor = getSubjectColor(subject);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEditDialog(context, doc.id, todo),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final newValue = !completed;
                  await FirebaseFirestore.instance
                      .collection('todos')
                      .doc(userId)
                      .collection('userTodos')
                      .doc(doc.id)
                      .update({'completed': newValue});
                  setState(() {});
                },
                child: Icon(
                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              _buildDdayTag(todo),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  final newFav = !favorite;
                  await FirebaseFirestore.instance
                      .collection('todos')
                      .doc(userId)
                      .collection('userTodos')
                      .doc(doc.id)
                      .update({'favorite': newFav});
                  setState(() {});
                },
                child: Icon(
                  favorite ? Icons.star : Icons.star_border,
                  color: Colors.yellow,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '선택';
    return DateFormat('yyyy-MM-dd HH:mm').format(date.toDate());
  }

  // ===== 이하 일정 수정 팝업, 삭제 등 기존 코드 그대로 유지 =====
  Future<void> _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> currentData,
  ) async {
    final titleController = TextEditingController(text: currentData['title']);
    final subjectController = TextEditingController(
      text: currentData['subject'],
    );
    final memoController = TextEditingController(
      text: currentData['memo'] ?? '',
    );
    String selectedCategory = currentData['category'] ?? '기타';
    DateTime? startDate = currentData['startDate']?.toDate();
    DateTime? endDate = currentData['endDate']?.toDate();
    bool notificationEnabled = currentData['notification'] ?? true;

    final List<String> categoryOptions = ['시험', '과제', '팀플', '기타'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('일정 수정', style: TextStyle(color: Colors.black)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '제목',
                    labelStyle: TextStyle(color: Colors.black),
                  ),
                ),
                TextField(
                  controller: subjectController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: '과목',
                    labelStyle: TextStyle(color: Colors.black),
                  ),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                    labelStyle: TextStyle(color: Colors.black),
                  ),
                  value: selectedCategory,
                  items: categoryOptions
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: memoController,
                  style: const TextStyle(color: Colors.black),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '메모',
                    labelStyle: TextStyle(color: Colors.black),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('시작일: ', style: TextStyle(color: Colors.black)),
                    TextButton(
                      onPressed: () async {
                        final picked = await _selectCustomDateTime(
                          startDate ?? DateTime.now(),
                        );
                        if (picked != null) setState(() => startDate = picked);
                      },
                      child: Text(
                        startDate != null
                            ? DateFormat(
                                'yyyy-MM-dd a hh:mm',
                              ).format(startDate!)
                            : '선택',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('마감일: ', style: TextStyle(color: Colors.black)),
                    TextButton(
                      onPressed: () async {
                        final picked = await _selectCustomDateTime(
                          endDate ?? DateTime.now(),
                        );
                        if (picked != null) setState(() => endDate = picked);
                      },
                      child: Text(
                        endDate != null
                            ? DateFormat('yyyy-MM-dd a hh:mm').format(endDate!)
                            : '선택',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => endDate = null),
                      child: const Text(
                        '선택',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text(
                    '알림',
                    style: TextStyle(color: Colors.black),
                  ),
                  value: notificationEnabled,
                  onChanged: (val) => setState(() => notificationEnabled = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final updatedTitle = titleController.text.trim();
                final updatedSubject = subjectController.text.trim();
                if (updatedTitle.isEmpty ||
                    updatedSubject.isEmpty ||
                    selectedCategory.isEmpty)
                  return;

                final updatedData = {
                  'title': updatedTitle,
                  'subject': updatedSubject,
                  'category': selectedCategory,
                  'memo': memoController.text.trim(),
                  'startDate': startDate != null
                      ? Timestamp.fromDate(startDate!)
                      : null,
                  'endDate': endDate != null
                      ? Timestamp.fromDate(endDate!)
                      : null,
                  'notification': notificationEnabled,
                };

                await TodoService.updateTodo(docId, updatedData);

                if (notificationEnabled &&
                    endDate != null &&
                    endDate!.isAfter(DateTime.now())) {
                  await _fcmService.scheduleNotification(
                    docId,
                    updatedTitle,
                    '마감일이 다가왔어요!',
                    endDate!,
                  );
                } else {
                  await _fcmService.cancelNotification(docId);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('일정이 저장되었습니다.')));
              },
              child: const Text('저장', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text(
                      '삭제 확인',
                      style: TextStyle(color: Colors.black),
                    ),
                    content: const Text(
                      '정말 이 일정을 삭제하시겠습니까?',
                      style: TextStyle(color: Colors.black),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          '취소',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          '삭제',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _deleteTodo(docId);
                  Navigator.pop(context);
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectCustomDateTime(DateTime initial) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _deleteTodo(String docId) async {
    await FirebaseFirestore.instance
        .collection('todos')
        .doc(userId)
        .collection('userTodos')
        .doc(docId)
        .delete();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
  }
}
