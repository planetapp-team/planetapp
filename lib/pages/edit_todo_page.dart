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

  final List<String> _categories = ['과제', '시험', '발표', '개인', '기타']; // ✅ 카테고리 목록
  String? _selectedCategory; // ✅ 선택된 카테고리 상태값

  @override
  void initState() {
    super.initState();
    final data = widget.todoData;

    // Firestore Timestamp를 DateTime으로 변환 후 초기값 세팅
    _titleController = TextEditingController(text: data['title'] ?? '');
    _subjectController = TextEditingController(text: data['subject'] ?? '');
    _selectedCategory =
        data['category'] ?? _categories.first; // ✅ 초기 선택 카테고리 설정
    _startDate = (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    _endDate = (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();
  }

  // 날짜 선택 다이얼로그 표시 함수
  // isStartDate: true면 시작일, false면 마감일 선택
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
          _startDate = picked; // 시작일 업데이트
        } else {
          _endDate = picked; // 마감일 업데이트
        }
      });
    }
  }

  // 저장 버튼 눌렀을 때 Firestore 문서 업데이트 처리
  Future<void> _saveTodo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docId = widget.todoData['docId']; // 수정할 문서 ID
    if (docId == null) return;

    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final category = _selectedCategory?.trim() ?? ''; // ✅ 드롭다운에서 선택된 카테고리 값 사용

    // 입력 검증: 빈 필드가 있으면 저장 중단하고 메시지 출력
    if (title.isEmpty || subject.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 필드를 입력하세요.')));
      return;
    }

    try {
      // Firestore 해당 문서 업데이트
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
            'date': Timestamp.fromDate(_startDate!), // date 필드는 startDate로 설정
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정이 수정되었습니다.')));

      Navigator.pop(context, true); // 수정 완료 결과 true 반환하며 이전 화면으로 돌아감
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
            // 제목 입력 필드
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            // 과목 입력 필드
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: '과목'),
            ),
            // ✅ 카테고리 선택 드롭다운 필드
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value; // 선택한 카테고리 업데이트
                });
              },
              decoration: const InputDecoration(labelText: '카테고리'),
            ),
            const SizedBox(height: 16),
            // 시작일 선택 UI
            Row(
              children: [
                const Text('시작일: '),
                TextButton(
                  onPressed: () => _selectDate(context, true),
                  child: Text(DateFormat('yyyy-MM-dd').format(_startDate!)),
                ),
              ],
            ),
            // 마감일 선택 UI
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
            // 저장 버튼
            ElevatedButton(onPressed: _saveTodo, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
