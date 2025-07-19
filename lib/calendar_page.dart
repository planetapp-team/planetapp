//calendar_page.dart
// 캘린더 페이지: 사용자의 일정 데이터를 날짜별로 시각화 및 리스트로 보여주는 화면
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart'; // 캘린더 UI 위젯
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 연동
import 'package:firebase_auth/firebase_auth.dart'; // 로그인된 사용자 정보 접근

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now(); // 캘린더에서 현재 보여지는 달
  DateTime? _selectedDay; // 사용자가 선택한 날짜

  // Firestore에서 불러온 일정 데이터를 저장할 변수
  // 날짜별로 리스트 형태로 일정 데이터를 보관
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // 현재 선택된 날짜의 일정 목록
  List<Map<String, dynamic>> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // 기본 선택 날짜는 오늘
    _fetchEventsFromFirestore(); // Firestore로부터 일정 불러오기
  }

  /// ✅ Firestore에서 사용자 일정 데이터 가져오기
  Future<void> _fetchEventsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // 로그인된 사용자 없으면 종료

    final snapshot = await FirebaseFirestore.instance
        .collection('todos')
        .doc(user.uid)
        .collection('userTodos')
        .get(); // 사용자 일정 데이터 전부 가져오기

    Map<DateTime, List<Map<String, dynamic>>> eventMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['date'] as Timestamp;

      // 날짜 정보만 추출하여 비교하기 쉽게 변환
      final date = DateTime(
        timestamp.toDate().year,
        timestamp.toDate().month,
        timestamp.toDate().day,
      );

      // 해당 날짜에 이미 일정이 있다면 리스트에 추가, 없으면 새로 리스트 생성
      eventMap[date] ??= [];
      eventMap[date]!.add(data);
    }

    // 화면 상태 갱신
    setState(() {
      _events = eventMap;
      _selectedEvents = _getEventsForDay(_selectedDay!);
    });
  }

  /// ✅ 특정 날짜에 해당하는 일정 리스트 반환
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  /// ✅ D-Day 계산 함수: 마감일 기준으로 D-3, D-Day, D+2 등으로 계산
  String _calculateDDay(DateTime targetDate) {
    final today = DateTime.now();
    final difference = targetDate.difference(today).inDays;

    if (difference == 0) {
      return 'D-Day';
    } else if (difference < 0) {
      return 'D${difference}'; // 마감일 지남
    } else {
      return 'D+$difference'; // 앞으로 남은 일수
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
          /// 📅 캘린더 위젯
          TableCalendar(
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay, // 날짜에 해당하는 이벤트 점 표시
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.transparent),
              selectedDecoration: BoxDecoration(color: Colors.blueAccent),
            ),
            calendarBuilders: CalendarBuilders(
              todayBuilder: (context, day, focusedDay) {
                return Container(); // 오늘 날짜 표시 없음
              },
              // 날짜별 일정 표시 및 D-day 표시
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
                      // 일정 제목과 D-day 최대 3개까지 표시
                      ...events
                          .take(displayCount)
                          .map(
                            (event) => Row(
                              children: [
                                Text(
                                  event['title'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blueAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _calculateDDay(
                                    (event['due_date'] as Timestamp).toDate(),
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
              // 날짜 클릭 시 해당 날짜로 상태 변경 및 이벤트 리스트 갱신
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents = _getEventsForDay(selectedDay);
              });
            },
          ),

          const SizedBox(height: 20),

          /// 📋 선택한 날짜의 일정 텍스트
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

          /// 📋 일정 리스트 (없으면 안내 메시지)
          Expanded(
            child: _selectedEvents.isEmpty
                ? Center(child: Text('$selectedDayString 는 저장된 일정이 없습니다.'))
                : ListView.builder(
                    itemCount: _selectedEvents.length,
                    itemBuilder: (context, index) {
                      final todo = _selectedEvents[index];
                      final dueDate = (todo['due_date'] as Timestamp).toDate();
                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(todo['title'] ?? ''),
                        subtitle: Text(
                          '${todo['subject']} · ${todo['category']}',
                        ),
                        trailing: Text(
                          _calculateDDay(dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: dueDate.isBefore(DateTime.now())
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
