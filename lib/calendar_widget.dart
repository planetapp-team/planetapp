// lib/calendar_widget.dart
// 홈 화면 일정 카드 디자인 + 완료/즐겨찾기 실시간 반영 + 과목별 점 표시 + 3개 초과 +n 표시
// ✅ 오늘 날짜 진한 노란색 / 선택 날짜(오늘 제외) 연한 노란색, 글씨 검정

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarWidget extends StatefulWidget {
  final void Function(DateTime)? onDateSelected;
  final DateTime? initialSelectedDate;
  final bool isHome; // 홈 화면 여부

  const CalendarWidget({
    Key? key,
    this.onDateSelected,
    this.initialSelectedDate,
    this.isHome = false,
  }) : super(key: key);

  @override
  _CalendarWidgetState createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _selectedEvents = [];
  late String userId;

  static const Color gray2 = Color(0xFFD9D9D9);
  static const Color black = Color(0xFF000000);
  static const Color yellow = Color(0xFFFFD741); // 오늘 날짜 진한 노란색
  static const Color lightYellow = Color(0xFFFFF59D); // 선택 날짜 연한 노란색

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialSelectedDate ?? DateTime.now();
    _selectedDay = _focusedDay;
    userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _fetchTodos();

    // 실시간 업데이트
    FirebaseFirestore.instance
        .collection('todos')
        .doc(userId)
        .collection('userTodos')
        .snapshots()
        .listen((snapshot) => _fetchTodos());
  }

  Future<void> _fetchTodos() async {
    if (userId.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('todos')
          .doc(userId)
          .collection('userTodos')
          .get();

      Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['startDate'] == null || data['endDate'] == null) continue;

        final startTs = data['startDate'] as Timestamp;
        final endTs = data['endDate'] as Timestamp;

        final startDate = DateTime(
          startTs.toDate().year,
          startTs.toDate().month,
          startTs.toDate().day,
        );
        final endDate = DateTime(
          endTs.toDate().year,
          endTs.toDate().month,
          endTs.toDate().day,
        );

        for (
          DateTime date = startDate;
          !date.isAfter(endDate);
          date = date.add(const Duration(days: 1))
        ) {
          events[date] ??= [];
          events[date]!.add({...data, 'docId': doc.id});
        }
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _selectedEvents = _getEventsForDay(_selectedDay!);
      });
    } catch (e) {
      print('Error fetching todos: $e');
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Color getSubjectColor(String subject) {
    final hash = subject.hashCode;
    final hue = (hash % 360).toDouble();
    final Color color = HSLColor.fromAHSL(1.0, hue, 0.6, 0.6).toColor();
    return color.withOpacity(0.85);
  }

  void _showEditRestrictionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('일정 수정/삭제는 일정 화면 일정 카드 클릭 시 가능합니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleCompleted(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('todos')
        .doc(userId)
        .collection('userTodos')
        .doc(docId)
        .update({'completed': !current});
  }

  Future<void> _toggleFavorite(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('todos')
        .doc(userId)
        .collection('userTodos')
        .doc(docId)
        .update({'favorite': !current});
  }

  Widget _buildDdayTag(Map<String, dynamic> event) {
    if (event['endDate'] == null) return const SizedBox.shrink();
    final ts = event['endDate'];
    if (ts is! Timestamp) return const SizedBox.shrink();

    final endDate = ts.toDate();
    final now = DateTime.now();
    final diff = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    if (diff < 0)
      return const Text(
        '종료',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    if (diff == 0)
      return const Text(
        'D-Day',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    return Text(
      'D-$diff',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents = _getEventsForDay(selectedDay);
              });
              widget.onDateSelected?.call(selectedDay);
            },
            onFormatChanged: (format) =>
                setState(() => _calendarFormat = format),
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,

            calendarStyle: CalendarStyle(
              todayDecoration: const BoxDecoration(
                color: yellow,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color:
                    _selectedDay != null &&
                        isSameDay(_selectedDay, DateTime.now())
                    ? yellow
                    : lightYellow,
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: black,
                fontWeight: FontWeight.bold,
              ),
              selectedTextStyle: const TextStyle(
                color: black,
                fontWeight: FontWeight.bold,
              ),
            ),

            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();

                final displayCount = events.length > 3 ? 3 : events.length;
                final remainingCount = events.length - displayCount;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...events.take(displayCount).map((eventObj) {
                      final event = eventObj as Map<String, dynamic>;
                      final subject = (event['subject'] ?? '기타').toString();
                      final color = getSubjectColor(subject);
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                    if (remainingCount > 0)
                      Text(
                        '+$remainingCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '선택한 날짜: ${_selectedDay?.toLocal().toIso8601String().substring(0, 10)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_selectedEvents.isEmpty)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: gray2,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 300,
                height: 31,
                child: const Center(
                  child: Text(
                    '일정이 없습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            )
          else
            ..._selectedEvents.map((event) {
              final subject = (event['subject'] ?? '기타').toString();
              final subjectColor = getSubjectColor(subject);
              final completed = event['completed'] ?? false;
              final favorite = event['favorite'] ?? false;
              final docId = event['docId'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: subjectColor,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await _toggleCompleted(docId, completed);
                        },
                        child: Icon(
                          completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          event['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      _buildDdayTag(event),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () async {
                          await _toggleFavorite(docId, favorite);
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
              );
            }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
