// 캘린더 위젯을 위한 필요한 패키지 import
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart'; // 캘린더 UI 라이브러리
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore DB 연동용
import 'package:firebase_auth/firebase_auth.dart'; // Firebase 로그인 사용자 정보 접근용

// Stateful 위젯 생성 - 날짜를 선택하고, 해당 날짜의 일정을 조회하기 위해 상태 관리가 필요함
class CalendarWidget extends StatefulWidget {
  final void Function(DateTime)? onDateSelected; // 날짜 선택 시 콜백 전달용
  final DateTime? initialSelectedDate; // 초기 선택된 날짜 외부에서 지정 가능

  const CalendarWidget({
    Key? key,
    this.onDateSelected,
    this.initialSelectedDate,
  }) : super(key: key);

  @override
  _CalendarWidgetState createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  CalendarFormat _calendarFormat = CalendarFormat.month; // 월간/주간 뷰 설정
  late DateTime _focusedDay; // 현재 보고 있는 달력 날짜
  DateTime? _selectedDay; // 사용자가 선택한 날짜
  Map<DateTime, List<Map<String, dynamic>>> _events =
      {}; // 날짜별 일정 데이터를 저장하는 Map
  List<Map<String, dynamic>> _selectedEvents = []; // 선택한 날짜의 일정 목록

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialSelectedDate ?? DateTime.now(); // 초기 포커스 날짜 설정
    _selectedDay = _focusedDay;

    // Firestore에서 사용자 일정 가져오기
    _fetchTodos().then((_) {
      setState(() {
        _selectedEvents = _getEventsForDay(_selectedDay!); // 현재 선택된 날짜의 일정만 표시
      });
    });
  }

  // Firestore에서 로그인 사용자의 일정들을 가져오는 함수
  Future<void> _fetchTodos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid; // 현재 로그인된 사용자 UID
    if (uid == null) return;

    try {
      // 사용자 할 일 문서(userTodos) 불러오기
      final snapshot = await FirebaseFirestore.instance
          .collection('todos')
          .doc(uid)
          .collection('userTodos')
          .get();

      Map<DateTime, List<Map<String, dynamic>>> events = {};

      // 각 일정 문서를 반복하며 날짜별로 정리
      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data['startDate'] == null) continue;
        final dynamic tsDynamic = data['startDate'];
        if (tsDynamic is! Timestamp) continue;

        final Timestamp ts = tsDynamic;
        final DateTime date = DateTime(
          ts.toDate().year,
          ts.toDate().month,
          ts.toDate().day,
        );

        // 해당 날짜에 일정 추가
        if (events[date] == null) {
          events[date] = [];
        }
        events[date]!.add({...data, 'docId': doc.id}); // 문서 ID도 저장
      }

      if (!mounted) return;
      setState(() {
        _events = events;
        _selectedEvents = _getEventsForDay(_selectedDay!);
      });
    } catch (e) {
      print('Error fetching todos: $e'); // 에러 출력
    }
  }

  // 특정 날짜의 일정을 반환하는 함수
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  // 일정 카드 클릭 시 상세 다이얼로그 표시
  void _showEventDetailDialog(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(event['title'] ?? '제목 없음'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('과목: ${event['subject'] ?? '없음'}'),
              Text('카테고리: ${event['category'] ?? '없음'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToEditPage(event); // 수정 페이지로 이동
              },
              child: const Text('수정'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // 상세창 닫기

                // 삭제 확인 다이얼로그
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('삭제 확인'),
                      content: const Text('정말 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    );
                  },
                );

                if (confirmed == true) {
                  _deleteTodo(event['docId']); // 삭제 함수 호출
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 일정 삭제 함수 (Firestore에서 삭제 후 재조회)
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

      await _fetchTodos(); // 삭제 후 다시 일정 불러오기
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  // 수정 페이지로 이동 후, 수정 시 일정 다시 불러옴
  void _navigateToEditPage(Map<String, dynamic> event) async {
    final result = await Navigator.pushNamed(
      context,
      '/edit_todo',
      arguments: event,
    );

    if (result == true) {
      await _fetchTodos();
    }
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
            eventLoader: _getEventsForDay, // 일정 마커 표시
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents = _getEventsForDay(selectedDay);
              });
              if (widget.onDateSelected != null) {
                widget.onDateSelected!(selectedDay); // 외부 콜백 실행
              }
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format; // 월간/주간 변경
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay; // 페이지 이동 시 포커스 날짜 갱신
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.deepPurple.shade100,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 4,
            ),
          ),
          const SizedBox(height: 16),
          // 선택한 날짜 표시
          Text(
            '선택한 날짜: ${_selectedDay?.toLocal().toIso8601String().substring(0, 10)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 일정이 없을 경우 메시지 표시
          if (_selectedEvents.isEmpty)
            Text(
              '${_selectedDay?.toLocal().toIso8601String().substring(0, 10)} 일정이 없습니다.',
            )
          else
            // 일정 카드 리스트
            ..._selectedEvents.map(
              (event) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: ListTile(
                  title: Text(event['title'] ?? '제목 없음'),
                  subtitle: Text(
                    '${event['category'] ?? ''} · ${event['subject'] ?? ''}',
                  ),
                  trailing: _buildDdayTag(event), // D-Day 태그 표시
                  onTap: () => _showEventDetailDialog(event), // 카드 클릭 시 상세 보기
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 일정의 D-Day 상태를 계산하여 표시
  Widget? _buildDdayTag(Map<String, dynamic> event) {
    if (event['startDate'] == null) return null;

    final dynamic tsDynamic = event['startDate'];
    if (tsDynamic is! Timestamp) return null;

    final Timestamp ts = tsDynamic;
    final DateTime date = ts.toDate();

    final DateTime now = DateTime.now();
    final DateTime dateOnly = DateTime(date.year, date.month, date.day);
    final DateTime nowOnly = DateTime(now.year, now.month, now.day);

    final int difference = dateOnly.difference(nowOnly).inDays;

    if (difference == 0) {
      return const Chip(
        label: Text('D-Day', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      );
    } else if (difference > 0) {
      return Chip(
        label: Text('D-$difference', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueGrey,
      );
    } else {
      return const Chip(
        label: Text('종료', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey,
      );
    }
  }
}
