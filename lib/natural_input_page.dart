// 기능:
// 자연어 텍스트 입력
//"자동 분류하기" 버튼
// 자동 뷴류 결과 표시
// 수정 가능한 드롭다운
// "저장하기"버튼

// natural_input_page.dart
// natural_input_page.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NaturalInputPage extends StatefulWidget {
  final DateTime? selectedDate; // 캘린더에서 선택된 날짜 전달받기

  const NaturalInputPage({super.key, this.selectedDate});

  @override
  State<NaturalInputPage> createState() => _NaturalInputPageState();
}

class _NaturalInputPageState extends State<NaturalInputPage> {
  final TextEditingController _inputController = TextEditingController();

  DateTime? _detectedDateTime; // 실제 날짜 객체로 관리

  String? detectedDate; // 화면에 보여줄 문자열
  String? detectedSubject;
  String? detectedCategory;

  bool showResult = false;

  final List<String> categoryOptions = ['시험', '과제', '팀플', '기타'];
  final List<String> subjectOptions = ['데이터통신', '캡스톤디자인', '운영체제', '기타', '일정'];

  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedDate != null) {
      _detectedDateTime = widget.selectedDate;
      detectedDate = _formatDate(widget.selectedDate!);
      // showResult는 자동 분류하기 버튼 누를 때만 true로 변경
      _inputController.text = '';
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dayKR = weekdays[date.weekday - 1];
    return '${DateFormat('yyyy-MM-dd').format(date)} ($dayKR)';
  }

  DateTime? extractDateFromInput(String input) {
    final regExp = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
    final match = regExp.firstMatch(input);
    if (match != null) {
      final month = int.parse(match.group(1)!);
      final day = int.parse(match.group(2)!);
      final now = DateTime.now();
      return DateTime(now.year, month, day);
    }
    return null;
  }

  void classifyInput() {
    String input = _inputController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 입력해주세요')));
      return;
    }

    setState(() {
      if (_detectedDateTime != null) {
        detectedDate = _formatDate(_detectedDateTime!);
      } else {
        DateTime? extractedDate = extractDateFromInput(input);
        if (extractedDate != null) {
          _detectedDateTime = extractedDate;
          detectedDate = _formatDate(extractedDate);
        } else {
          detectedDate = '날짜 인식 안됨';
          _detectedDateTime = null;
        }
      }

      detectedSubject = null;
      for (var subject in subjectOptions) {
        if (input.contains(subject)) {
          detectedSubject = subject;
          break;
        }
      }

      if (detectedSubject == null) {
        String temp = input
            .replaceAll(RegExp(r'\d{1,2}월\s*\d{1,2}일'), '')
            .trim();
        List<String> parts = temp.split(RegExp(r'\s+'));
        detectedSubject = parts.isNotEmpty ? parts[0] : '일정';
      }

      detectedCategory = null;
      for (var category in categoryOptions) {
        if (input.contains(category)) {
          detectedCategory = category;
          break;
        }
      }
      detectedCategory ??= '기타';

      showResult = true;
      isEditing = false;
    });
  }

  Future<void> saveTodo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    if (_detectedDateTime == null ||
        detectedSubject == null ||
        detectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자동 분류를 먼저 실행하고 정확한 값을 입력해주세요')),
      );
      return;
    }

    try {
      final todoData = {
        'title': _inputController.text,
        'date': Timestamp.fromDate(_detectedDateTime!),
        'subject': detectedSubject,
        'category': detectedCategory,
        'createdAt': Timestamp.now(),
      };

      final todoRef = FirebaseFirestore.instance
          .collection('todos')
          .doc(user.uid)
          .collection('userTodos');

      await todoRef.add(todoData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정이 저장되었습니다!')));

      setState(() {
        _inputController.clear();
        detectedDate = null;
        detectedSubject = null;
        detectedCategory = null;
        showResult = false;
        _detectedDateTime = null;
        isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 중 오류 발생: $e')));
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _detectedDateTime ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _detectedDateTime = picked;
        detectedDate = _formatDate(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자연어 일정 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: '일정을 자연어로 입력하세요',
                hintText: '예: 7월 9일 데이터통신 과제 제출',
              ),
              readOnly: !isEditing && showResult,
              maxLines: null,
              autofocus: isEditing || !showResult,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: classifyInput,
              child: const Text('자동 분류하기'),
            ),
            const SizedBox(height: 20),
            if (showResult)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📌 자동 분류 결과',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('날짜: '),
                      if (!isEditing) Text(detectedDate ?? ''),
                      if (isEditing)
                        TextButton(
                          onPressed: _selectDate,
                          child: Text(detectedDate ?? '날짜 선택'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('과목: '),
                      if (!isEditing) Text(detectedSubject ?? ''),
                      if (isEditing)
                        DropdownButton<String>(
                          value: subjectOptions.contains(detectedSubject)
                              ? detectedSubject
                              : subjectOptions.first,
                          onChanged: (value) {
                            setState(() {
                              detectedSubject = value;
                            });
                          },
                          items: subjectOptions
                              .map(
                                (subject) => DropdownMenuItem(
                                  value: subject,
                                  child: Text(subject),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('카테고리: '),
                      if (!isEditing) Text(detectedCategory ?? ''),
                      if (isEditing)
                        DropdownButton<String>(
                          value: categoryOptions.contains(detectedCategory)
                              ? detectedCategory
                              : categoryOptions.first,
                          onChanged: (value) {
                            setState(() {
                              detectedCategory = value;
                            });
                          },
                          items: categoryOptions
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!isEditing)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isEditing = true;
                            });
                          },
                          child: const Text('수정하기'),
                        ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: saveTodo,
                        child: const Text('저장하기'),
                      ),
                      if (isEditing) const SizedBox(width: 10),
                      if (isEditing)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isEditing = false;
                            });
                          },
                          child: const Text('취소'),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
