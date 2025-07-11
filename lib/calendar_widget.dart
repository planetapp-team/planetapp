//calendar_widget.dart
//캘린더에 해당 날짜에 저장된 일정이 잇다면,
//그 날짜 아래에 일정 제목들이 표시되도록
// lib/calendar_widget.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarWidget extends StatefulWidget {
  final void Function(DateTime)? onDateSelected;

  const CalendarWidget({super.key, this.onDateSelected});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 날짜별 일정 맵 (날짜 -> 일정 리스트)
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _todosForSelectedDay = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAllTodosForMonth(_focusedDay);
    _loadTodosForDay(_selectedDay!);
  }

  /// 해당 월 모든 일정 불러오기 (미리보기용)
  Future<void> _fetchAllTodosForMonth(DateTime focusedDay) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firstDay = DateTime(focusedDay.year, focusedDay.month, 1);
    final lastDay = DateTime(focusedDay.year, focusedDay.month + 1, 0);

    final snapshot = await FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> eventMap = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final ts = data['date'] as Timestamp;
      final date = DateTime(
        ts.toDate().year,
        ts.toDate().month,
        ts.toDate().day,
      );
      eventMap[date] ??= [];
      eventMap[date]!.add(data);
    }

    setState(() => _events = eventMap);
  }

  /// 선택한 날짜 일정 불러오기
  Future<void> _loadTodosForDay(DateTime selectedDate) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final startOfDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final todosList = snapshot.docs.map((doc) => doc.data()).toList();
    setState(() => _todosForSelectedDay = todosList);
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime(2020, 1, 1),
          lastDay: DateTime(2100, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final events = _getEventsForDay(day);
              final totalCount = events.length;
              final displayCnt = totalCount > 3 ? 3 : totalCount;
              final hasMore = totalCount > 3;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSameDay(day, _selectedDay)
                      ? Colors.orange.withOpacity(0.3)
                      : isSameDay(day, DateTime.now())
                      ? Colors.blue.withOpacity(0.3)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSameDay(day, _selectedDay)
                            ? Colors.orange
                            : isSameDay(day, DateTime.now())
                            ? Colors.blue
                            : Colors.black,
                      ),
                    ),
                    ...events
                        .take(displayCnt)
                        .map(
                          (e) => Text(
                            e['title'] ?? '제목 없음',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blueAccent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    if (hasMore)
                      Text(
                        '+${totalCount - 3}개',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _loadTodosForDay(selectedDay);
            widget.onDateSelected?.call(selectedDay);
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
            _fetchAllTodosForMonth(focusedDay);
          },
        ),

        const SizedBox(height: 10),
        if (_selectedDay != null)
          Text(
            '선택한 날짜: ${_selectedDay!.toLocal()}'.split(' ')[0],
            style: const TextStyle(fontSize: 16),
          ),

        const SizedBox(height: 10),
        if (_todosForSelectedDay.isEmpty)
          const Text(
            '이 날짜에 저장된 일정이 없습니다.',
            style: TextStyle(color: Colors.grey),
          ),
        ..._todosForSelectedDay.map((todo) {
          final title = todo['title'] ?? '제목 없음';
          final subject = todo['subject'] ?? '과목 없음';
          final category = todo['category'] ?? '카테고리 없음';
          return Card(
            child: ListTile(
              title: Text(title),
              subtitle: Text('$subject • $category'),
            ),
          );
        }).toList(),
      ],
    );
  }
}
