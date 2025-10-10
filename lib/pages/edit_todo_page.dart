// lib/pages/edit_todo_page.dart
// 기존 todoData를 받아 수정 폼 초기화
// 제목, 과목, 카테고리, 시작일, 마감일, 메모 편집 가능
// 저장 시 Firestore 문서 업데이트
// 수정 완료 시 true 반환 후 이전 화면으로 돌아감
// 날짜 + 시간 선택 다이얼로그 제공
// 빈 필드 입력 검증 포함
// 카테고리 입력 필드를 드롭다운 선택으로 변경
// 시간 선택 안함 기능 추가
// 알림 on/off 토글 버튼 추가
// 알림 예약 및 취소 연동 추가

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// FcmService 임포트
import '../services/fcm_service.dart';

class EditTodoPage extends StatefulWidget {
  final Map<String, dynamic> todoData; // 수정할 할 일 데이터

  const EditTodoPage({Key? key, required this.todoData}) : super(key: key);

  @override
  _EditTodoPageState createState() => _EditTodoPageState();
}

class _EditTodoPageState extends State<EditTodoPage> {
  late TextEditingController _titleController; // 제목 입력
  late TextEditingController _subjectController; // 과목 입력
  late TextEditingController _memoController; // 메모 입력

  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _categories = ['과제', '시험', '팀플', '기타'];
  String? _selectedCategory;

  bool _notificationEnabled = true;

  // ✅ FcmService 인스턴스
  late FcmService _fcmService;

  @override
  void initState() {
    super.initState();

    // FlutterLocalNotificationsPlugin 초기화
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _fcmService = FcmService(
      flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
    );

    final data = widget.todoData;

    _titleController = TextEditingController(text: data['title'] ?? '');
    _subjectController = TextEditingController(text: data['subject'] ?? '');
    _memoController = TextEditingController(text: data['memo'] ?? '');

    _selectedCategory = (_categories.contains(data['category']))
        ? data['category']
        : _categories.first;

    _startDate = (data['startDate'] as Timestamp?)?.toDate();
    _endDate = (data['endDate'] as Timestamp?)?.toDate();

    _notificationEnabled = data['notification'] ?? true;
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? DateTime.now());

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialDate.hour,
        minute: initialDate.minute,
      ),
    );
    if (pickedTime == null) return;

    final combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStartDate) {
        _startDate = combinedDateTime;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = combinedDateTime;
      }
    });
  }

  Future<void> _saveTodo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docId = widget.todoData['docId'];
    if (docId == null) return;

    final title = _titleController.text.trim();
    final subject = _subjectController.text.trim();
    final category = _selectedCategory?.trim() ?? '';
    final memo = _memoController.text.trim();

    if (title.isEmpty || subject.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 필드를 입력하세요.')));
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작일과 마감일을 선택하세요.')));
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
            'memo': memo,
            'startDate': Timestamp.fromDate(_startDate!),
            'endDate': Timestamp.fromDate(_endDate!),
            'date': Timestamp.fromDate(_startDate!),
            'notification': _notificationEnabled,
          });

      // ✅ 알림 예약 또는 취소
      if (_notificationEnabled && _endDate!.isAfter(DateTime.now())) {
        await _fcmService.scheduleNotification(
          docId,
          title,
          '마감일이 다가왔어요!',
          _endDate!,
        );
      } else {
        await _fcmService.cancelNotification(docId);
      }

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
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일정 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 제목
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 16),

            // 시작일
            Row(
              children: [
                const Text('시작일: '),
                TextButton(
                  onPressed: () => _selectDateTime(context, true),
                  child: Text(
                    _startDate != null
                        ? DateFormat('yyyy-MM-dd a hh:mm').format(_startDate!)
                        : '선택 안됨',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _startDate = null),
                  child: const Text('선택 안함'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 마감일
            Row(
              children: [
                const Text('마감일: '),
                TextButton(
                  onPressed: () => _selectDateTime(context, false),
                  child: Text(
                    _endDate != null
                        ? DateFormat('yyyy-MM-dd a hh:mm').format(_endDate!)
                        : '선택 안됨',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _endDate = null),
                  child: const Text('선택 안함'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 과목
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: '과목'),
            ),
            const SizedBox(height: 16),

            // 카테고리
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
              decoration: const InputDecoration(labelText: '카테고리'),
            ),
            const SizedBox(height: 16),

            // 메모
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 16),

            // 알림 토글
            SwitchListTile(
              title: const Text('알림 받기'),
              value: _notificationEnabled,
              onChanged: (value) =>
                  setState(() => _notificationEnabled = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            ElevatedButton(onPressed: _saveTodo, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
