// natural_input_page.dart
// 문장으로 일정 저장 가능
// 자동 분류
// 자동 분류 결과
// 시작일,마감일, 과목, 제목, 카테고리, 메모, 알림 받기(홈 화면 상단 배너 반영)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'calendar_widget.dart';
import 'services/category_classifier.dart';
import 'utils/theme.dart'; // AppColors 사용

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NaturalInputPage extends StatefulWidget {
  final DateTime? selectedDate;
  final void Function(DateTime) onDateSelected;

  const NaturalInputPage({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<NaturalInputPage> createState() => _NaturalInputPageState();
}

class _NaturalInputPageState extends State<NaturalInputPage> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  String? detectedDate;
  String? detectedSubject;
  String? detectedCategory;

  bool showResult = false;
  bool isEditing = false;
  bool _notificationEnabled = true;

  final List<String> categoryOptions = ['시험', '과제', '팀플', '기타'];
  final List<String> subjectOptions = [];

  @override
  void initState() {
    super.initState();
    tzdata.initializeTimeZones();
    _initLocalNotifications();

    if (widget.selectedDate != null) {
      _startDate = widget.selectedDate;
      detectedDate = _formatDate(widget.selectedDate!);
      _inputController.text = '';
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _initLocalNotifications() {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse response) async {},
    );
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

  Future<void> classifyInput() async {
    String input = _inputController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 입력해주세요')));
      return;
    }

    setState(() {
      if (_startDate != null) {
        detectedDate = _formatDate(_startDate!);
      } else {
        DateTime? extractedDate = extractDateFromInput(input);
        if (extractedDate != null) {
          _startDate = extractedDate;
          detectedDate = _formatDate(extractedDate);
        } else {
          detectedDate = '날짜 인식 안됨';
          _startDate = null;
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
            .replaceAll(RegExp(r'\d{1,2}월\s*\d{1,2}일'), ' ')
            .trim();
        List<String> parts = temp.split(RegExp(r'\s+'));
        detectedSubject = parts.isNotEmpty ? parts[0] : '일정';
      }

      detectedCategory = classifyCategory(input);

      showResult = true;
      isEditing = false;
      _memoController.text = '';
      _notificationEnabled = true;
    });

    // 🔹 마감일 없는 경우 안내 팝업 (저장은 사용자가 직접 눌러야 함)
    if (_endDate == null) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('알림', style: TextStyle(color: Colors.black)),
          content: const Text(
            '마감일을 설정하지 않으면 오늘 일정으로 자동 분류됩니다.\n'
            '일정 화면에서 수정 시 날짜 미정 일정으로 이동됩니다.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> saveTodo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    if (_startDate == null ||
        detectedSubject == null ||
        detectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자동 분류를 먼저 실행하고 정확한 값을 입력해주세요')),
      );
      return;
    }

    // 🔹 마감일 없는 경우, 저장 시점에 자동 오늘일 설정
    if (_endDate == null) {
      final now = DateTime.now();
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 0);
    }

    try {
      final deadlineDate = _endDate!;

      final todoData = {
        'title': _inputController.text,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(deadlineDate),
        'subject': detectedSubject,
        'category': detectedCategory,
        'memo': _memoController.text.trim(),
        'notification': _notificationEnabled,
        'createdAt': Timestamp.now(),
      };

      final todoRef = FirebaseFirestore.instance
          .collection('todos')
          .doc(user.uid)
          .collection('userTodos');

      final newDocRef = await todoRef.add(todoData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정이 저장되었습니다!')));

      if (_notificationEnabled) {
        await _scheduleNotification(
          newDocRef.id,
          _inputController.text,
          deadlineDate,
        );
      } else {
        await _cancelNotification(newDocRef.id);
      }

      widget.onDateSelected(_startDate!);

      setState(() {
        _inputController.clear();
        _memoController.clear();
        detectedDate = null;
        detectedSubject = null;
        detectedCategory = null;
        showResult = false;
        _startDate = null;
        _endDate = null;
        isEditing = false;
        _notificationEnabled = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 중 오류 발생: $e')));
    }
  }

  Future<void> _scheduleNotification(
    String id,
    String title,
    DateTime deadline,
  ) async {
    final notificationId = id.hashCode;
    final scheduledTime = deadline.subtract(const Duration(minutes: 5));
    if (scheduledTime.isBefore(DateTime.now())) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      '일정 마감 5분 전 알림',
      '$title 일정이 곧 마감됩니다.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'deadline_channel',
          'Deadline Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'deadline_payload',
    );
  }

  Future<void> _cancelNotification(String id) async {
    final notificationId = id.hashCode;
    await flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  /// 날짜/시간 선택 커스텀 다이얼로그 (확인/취소 한글 표시)
  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: ColorScheme.light(
              primary: AppColors.yellow,
              onPrimary: AppColors.black,
              onSurface: AppColors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _startDate != null
            ? TimeOfDay(hour: _startDate!.hour, minute: _startDate!.minute)
            : TimeOfDay.now(),
        cancelText: '취소',
        confirmText: '확인',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              dialogBackgroundColor: Colors.white,
              colorScheme: ColorScheme.light(
                primary: AppColors.yellow,
                onPrimary: AppColors.black,
                onSurface: AppColors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: Colors.black),
              ),
            ),
            child: child!,
          );
        },
      );

      setState(() {
        _startDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? 0,
          pickedTime?.minute ?? 0,
        );
        detectedDate = _formatDate(_startDate!);
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 시작일을 선택해주세요')));
      return;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime(_startDate!.year + 5),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: ColorScheme.light(
              primary: AppColors.yellow,
              onPrimary: AppColors.black,
              onSurface: AppColors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _endDate != null
            ? TimeOfDay(hour: _endDate!.hour, minute: _endDate!.minute)
            : const TimeOfDay(hour: 23, minute: 59),
        cancelText: '취소',
        confirmText: '확인',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              dialogBackgroundColor: Colors.white,
              colorScheme: ColorScheme.light(
                primary: AppColors.yellow,
                onPrimary: AppColors.black,
                onSurface: AppColors.black,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: Colors.black),
              ),
            ),
            child: child!,
          );
        },
      );

      setState(() {
        _endDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime?.hour ?? 23,
          pickedTime?.minute ?? 59,
        );
      });
    }
  }

  String getDDayText(DateTime start, DateTime end) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final endDate = DateTime(end.year, end.month, end.day);

    if (todayDate.isBefore(endDate)) {
      final diff = endDate.difference(todayDate).inDays;
      return diff == 0 ? 'D-Day' : 'D-$diff';
    } else if (todayDate.isAfter(endDate)) {
      final diff = todayDate.difference(endDate).inDays;
      return 'D+${diff}';
    } else {
      return 'D-Day';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 추가', style: TextStyle(color: AppColors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: '일정을 자연어로 입력하세요',
                labelStyle: TextStyle(color: AppColors.black),
              ),
              style: const TextStyle(color: AppColors.black),
              readOnly: !isEditing && showResult,
              maxLines: null,
              autofocus: isEditing || !showResult,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
              ),
              onPressed: classifyInput,
              child: const Text(
                '자동 분류',
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (showResult)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📌 자동 분류 결과',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            '시작일: ',
                            style: TextStyle(color: AppColors.black),
                          ),
                          TextButton(
                            onPressed: _selectStartDate,
                            child: Text(
                              _startDate != null
                                  ? DateFormat(
                                      'yyyy-MM-dd hh:mm a',
                                    ).format(_startDate!)
                                  : '선택 안됨',
                              style: const TextStyle(color: AppColors.black),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text(
                            '마감일: ',
                            style: TextStyle(color: AppColors.black),
                          ),
                          TextButton(
                            onPressed: _selectEndDate,
                            child: Text(
                              _endDate != null
                                  ? DateFormat(
                                          'yyyy-MM-dd hh:mm a',
                                        ).format(_endDate!) +
                                        " (" +
                                        getDDayText(_startDate!, _endDate!) +
                                        ")"
                                  : '선택 안됨',
                              style: const TextStyle(color: AppColors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            '과목: ',
                            style: TextStyle(color: AppColors.black),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              detectedSubject ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            '카테고리: ',
                            style: TextStyle(color: AppColors.black),
                          ),
                          DropdownButton<String>(
                            value: categoryOptions.contains(detectedCategory)
                                ? detectedCategory
                                : categoryOptions.first,
                            items: categoryOptions
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                detectedCategory = value;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _memoController,
                        decoration: const InputDecoration(
                          labelText: '메모',
                          border: OutlineInputBorder(),
                          labelStyle: TextStyle(color: AppColors.black),
                        ),
                        style: const TextStyle(color: AppColors.black),
                        maxLines: null,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text(
                          '알림 받기',
                          style: TextStyle(color: AppColors.black),
                        ),
                        value: _notificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _notificationEnabled = value;
                          });
                        },
                        activeColor: AppColors.yellow,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gray2,
                            ),
                            onPressed: () => setState(() => isEditing = true),
                            child: const Text(
                              '수정',
                              style: TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                            ),
                            onPressed: saveTodo,
                            child: const Text(
                              '저장',
                              style: TextStyle(
                                color: AppColors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
