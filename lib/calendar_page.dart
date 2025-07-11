//캘린더 페이지 만들기
//firebase 일정 데이터를 불러와서 날짜별 점 표시하고,
//선택한 날짜의 일정 리스트 보여주기 기능 추가
// lib/calendar_page.dart
// lib/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 날짜별 일정 맵 (날짜 -> 일정 리스트)
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEventsFromFirestore();
  }

  // Firestore에서 일정 데이터 가져오기
  Future<void> _fetchEventsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('todos')
        .doc(user.uid)
        .collection('userTodos')
        .get();

    Map<DateTime, List<Map<String, dynamic>>> eventMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['date'] as Timestamp;
      final date = DateTime(
        timestamp.toDate().year,
        timestamp.toDate().month,
        timestamp.toDate().day,
      );

      if (eventMap[date] == null) {
        eventMap[date] = [];
      }
      eventMap[date]!.add(data);
    }

    setState(() {
      _events = eventMap;
      _selectedEvents = _events[_selectedDay] ?? [];
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캘린더')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final events = _getEventsForDay(day);
                final totalCount = events.length;
                final displayCount = totalCount > 3 ? 3 : totalCount;
                final hasMore = totalCount > 3;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    // 오늘, 선택된 날짜 표시를 위해 간단히 색깔 변경 가능
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
                          .take(displayCount)
                          .map(
                            (event) => Text(
                              event['title'] ?? '',
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
                _selectedEvents = _getEventsForDay(selectedDay);
              });
            },
          ),
          const SizedBox(height: 20),
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '선택한 날짜: ${_selectedDay!.toLocal()}'.split(' ')[0],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _selectedEvents.isEmpty
                ? const Center(child: Text('선택한 날짜에 일정이 없습니다.'))
                : ListView.builder(
                    itemCount: _selectedEvents.length,
                    itemBuilder: (context, index) {
                      final todo = _selectedEvents[index];
                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(todo['title'] ?? ''),
                        subtitle: Text(
                          '${todo['subject']} · ${todo['category']}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
