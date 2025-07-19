// lib/pages/edit_todo_page.dart
// 기존 todoData를 받아 수정 폼 초기화
// 제목, 과목, 카테고리, 시작일, 마감일 편집 가능
// 저장 시 Firestore 문서 업데이트
// 수정 완료 시 true 반환 후 이전 화면으로 돌아감
// 날짜 선택 다이얼로그 제공
// 빈 필드 입력 검증 포함
// ✅ 카테고리 입력 필드를 드롭다운 선택으로 변경

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EditTodoPage extends StatefulWidget {
  final Map<String, dynamic> todoData; // 수정할 할 일 데이터

  const EditTodoPage({Key? key, required this.todoData}) : super(key: key);

  @override
  _EditTodoPageState createState() => _EditTodoPageState();
}

class _EditTodoPageState extends State<EditTodoPage> {
  late TextEditingController _titleController; // 제목 입력 컨트롤러
  late TextEditingController _subjectController; // 과목 입력 컨트롤러

  DateTime? _startDate; // 시작일
  DateTime? _endDate; // 마감일

  final List<String> _categories = ['과제', '시험', '팀플', '기타']; // ✅ 카테고리 목록
  String? _selectedCategory; // ✅ 선택된 카테고리 상태값

  @override
  void initState() {
    super.initState();
    final data = widget.todoData;

    _titleController = TextEditingController(text: data['title'] ?? '');
    _subjectController = TextEditingController(text: data['subject'] ?? '');

    // ★ 수정된 부분: category 값이 _categories에 없으면 첫 번째 값으로 초기화
    _selectedCategory = (_categories.contains(data['category']))
        ? data['category']
        : _categories.first;

    _startDate = (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    _endDate = (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate! : _endDate!;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020), // 선택 가능한 최소 날짜
      lastDate: DateTime(2100), // 선택 가능한 최대 날짜
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTodo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docId = widget.todoData['docId'];
    if (docId == null) return;

    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final category = _selectedCategory?.trim() ?? '';

    if (title.isEmpty || subject.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 필드를 입력하세요.')));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(uid)
          .collection('userTodos')
          .doc(docId)
          .update({
            'title': title,
            'subject': subject,
            'category': category,
            'startDate': Timestamp.fromDate(_startDate!),
            'endDate': Timestamp.fromDate(_endDate!),
            'date': Timestamp.fromDate(_startDate!),
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정이 수정되었습니다.')));

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일정 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: '과목'),
            ),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              decoration: const InputDecoration(labelText: '카테고리'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('시작일: '),
                TextButton(
                  onPressed: () => _selectDate(context, true),
                  child: Text(DateFormat('yyyy-MM-dd').format(_startDate!)),
                ),
              ],
            ),
            Row(
              children: [
                const Text('마감일: '),
                TextButton(
                  onPressed: () => _selectDate(context, false),
                  child: Text(DateFormat('yyyy-MM-dd').format(_endDate!)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _saveTodo, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
