// lib/calendar_widget.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarWidget extends StatefulWidget {
  final void Function(DateTime)? onDateSelected;
  final DateTime? initialSelectedDate;
  final bool isHome; // 홈 화면 여부 추가

  const CalendarWidget({
    Key? key,
    this.onDateSelected,
    this.initialSelectedDate,
    this.isHome = false, // 기본값 false
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

  static const Color gray2 = Color(0xFFD9D9D9);
  static const Color black = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialSelectedDate ?? DateTime.now();
    _selectedDay = _focusedDay;

    _fetchTodos().then((_) {
      setState(() {
        _selectedEvents = _getEventsForDay(_selectedDay!);
      });
    });
  }

  Future<void> _fetchTodos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('todos')
          .doc(uid)
          .collection('userTodos')
          .get();

      Map<DateTime, List<Map<String, dynamic>>> events = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['startDate'] == null || data['endDate'] == null) continue;

        final dynamic startTsDynamic = data['startDate'];
        final dynamic endTsDynamic = data['endDate'];
        if (startTsDynamic is! Timestamp || endTsDynamic is! Timestamp)
          continue;

        final DateTime startDate = DateTime(
          startTsDynamic.toDate().year,
          startTsDynamic.toDate().month,
          startTsDynamic.toDate().day,
        );
        final DateTime endDate = DateTime(
          endTsDynamic.toDate().year,
          endTsDynamic.toDate().month,
          endTsDynamic.toDate().day,
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

  Future<void> _deleteTodo(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(uid)
          .collection('userTodos')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
      await _fetchTodos();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  void _navigateToEditPage(Map<String, dynamic> event) async {
    final result = await Navigator.pushNamed(
      context,
      '/edit_todo',
      arguments: event,
    );
    if (result == true) await _fetchTodos();
  }

  Color getSubjectColor(String subject) {
    final hash = subject.hashCode;
    final hue = (hash % 360).toDouble();
    final Color color = HSLColor.fromAHSL(1.0, hue, 0.6, 0.6).toColor();
    final Color tonedColor = Color.lerp(
      color,
      const Color.fromARGB(255, 255, 255, 255),
      0.1,
    )!;
    return tonedColor.withOpacity(0.85);
  }

  void _showEditRestrictionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('일정 수정/삭제는 일정 화면 일정 카드 클릭 시 가능합니다.'),
        duration: Duration(seconds: 2),
      ),
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
              todayDecoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
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
            ..._selectedEvents.map((eventObj) {
              final event = eventObj as Map<String, dynamic>;
              final subject = (event['subject'] ?? '기타').toString();
              final subjectColor = getSubjectColor(subject);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: subjectColor,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GestureDetector(
                  onTap: () {
                    if (widget.isHome) {
                      _showEditRestrictionMessage();
                    } else {
                      _navigateToEditPage(event);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${event['subject'] ?? ''}/${event['category'] ?? ''}/${event['title'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildDdayTag(event),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// ✅ D-day 계산: 마감일(endDate) 기준
  Widget _buildDdayTag(Map<String, dynamic> event) {
    if (event['endDate'] == null) return const SizedBox.shrink();

    final dynamic tsDynamic = event['endDate'];
    if (tsDynamic is! Timestamp) return const SizedBox.shrink();

    final DateTime endDate = tsDynamic.toDate();
    final DateTime now = DateTime.now();
    final DateTime endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    final DateTime nowOnly = DateTime(now.year, now.month, now.day);
    final int difference = endOnly.difference(nowOnly).inDays;

    if (difference < 0) {
      return const Text(
        '종료',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    } else if (difference == 0) {
      return const Text(
        'D-Day',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    } else {
      return Text(
        'D-$difference',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }
}
