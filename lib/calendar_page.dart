//calendar_page.dart
// 캘린더 페이지:
// 사용자의 일정 데이터를 날짜별로 시각화 및
// 리스트로 보여주는 화면
// 로그인한 사용자별 데이터를 보여주는 화면형식(UI)
// 캘린더 화면에서 보여주는
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart'; // 캘린더 위젯
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 사용
import 'package:firebase_auth/firebase_auth.dart'; // 로그인된 사용자 정보 접근

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now(); // 현재 보여지는 달
  DateTime? _selectedDay; // 선택된 날짜

  // 날짜별 일정 저장 맵 (예: 2025-07-27 → [일정1, 일정2])
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // 현재 선택된 날짜의 일정 리스트
  List<Map<String, dynamic>> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEventsFromFirestore();
  }

  /// ✅ Firestore에서 일정 데이터를 가져와 날짜별로 맵에 저장
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

      // 🔑 구조에 맞춰 필드 이름 변경
      final startTimestamp = data['startDate'] as Timestamp;
      final endTimestamp = data['endDate'] as Timestamp;

      final startDate = _normalizeDate(startTimestamp.toDate());
      final endDate = _normalizeDate(endTimestamp.toDate());

      // 🔁 시작일 ~ 마감일 사이 날짜 전부에 일정 넣기
      DateTime currentDate = startDate;
      while (!currentDate.isAfter(endDate)) {
        final normalizedDate = _normalizeDate(currentDate);
        eventMap[normalizedDate] ??= [];
        eventMap[normalizedDate]!.add(data);
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    setState(() {
      _events = eventMap;
      _selectedEvents = _getEventsForDay(_selectedDay!);
    });
  }

  /// ✅ 날짜를 00:00:00으로 정규화 (시간 무시)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// ✅ 선택된 날짜에 해당하는 일정 리스트 반환
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
  }

  /// ✅ D-Day 계산 함수
  String _calculateDDay(DateTime targetDate) {
    final today = _normalizeDate(DateTime.now());
    final difference = targetDate.difference(today).inDays;

    if (difference == 0) {
      return 'D-Day';
    } else if (difference > 0) {
      return 'D-$difference';
    } else {
      return 'D+${-difference}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayString =
        _selectedDay?.toLocal().toIso8601String().substring(0, 10) ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('캘린더')),
      body: Column(
        children: [
          /// 📅 캘린더 UI
          TableCalendar(
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay, // 날짜별 점 표시
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.transparent),
              selectedDecoration: BoxDecoration(color: Colors.blueAccent),
            ),
            calendarBuilders: CalendarBuilders(
              todayBuilder: (context, day, focusedDay) {
                return Container(); // 오늘 날짜 강조 제거
              },
              // 날짜 박스 커스터마이징
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
                    color: Colors.transparent,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day}', // 날짜 숫자
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      ...events
                          .take(displayCount)
                          .map(
                            (event) => Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    event['title'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.blueAccent,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _calculateDDay(
                                    (_normalizeDate(
                                      (event['endDate'] as Timestamp).toDate(),
                                    )),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      if (hasMore)
                        const Text(
                          '+더보기',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
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

          /// 📝 선택한 날짜 일정 리스트
          if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$selectedDayString 일정',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),

          /// 📋 일정 리스트 or 없을 때 메시지
          Expanded(
            child: _selectedEvents.isEmpty
                ? Center(child: Text('$selectedDayString 는 저장된 일정이 없습니다.'))
                : ListView.builder(
                    itemCount: _selectedEvents.length,
                    itemBuilder: (context, index) {
                      final todo = _selectedEvents[index];
                      final endDate = (_normalizeDate(
                        (todo['endDate'] as Timestamp).toDate(),
                      ));

                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(todo['title'] ?? ''),
                        subtitle: Text(
                          '${todo['subject']} · ${todo['category']}',
                        ),
                        trailing: Text(
                          _calculateDDay(endDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: endDate.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.green,
                          ),
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
