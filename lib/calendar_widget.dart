// calendar_widget.dart
// 캘린더 위젯을 위한 필요한 패키지
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart'; // 캘린더 UI 라이브러리
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore DB 연동용
import 'package:firebase_auth/firebase_auth.dart'; // Firebase 로그인 사용자 정보 접근용

class CalendarWidget extends StatefulWidget {
  final void Function(DateTime)? onDateSelected;
  final DateTime? initialSelectedDate;

  const CalendarWidget({
    Key? key,
    this.onDateSelected,
    this.initialSelectedDate,
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

        if (data['startDate'] == null) continue;
        final dynamic tsDynamic = data['startDate'];
        if (tsDynamic is! Timestamp) continue;

        final Timestamp ts = tsDynamic;
        final DateTime date = DateTime(
          ts.toDate().year,
          ts.toDate().month,
          ts.toDate().day,
        );

        if (events[date] == null) {
          events[date] = [];
        }
        events[date]!.add({...data, 'docId': doc.id});
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
                _navigateToEditPage(event);
              },
              child: const Text('수정'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
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
                  _deleteTodo(event['docId']);
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents = _getEventsForDay(selectedDay);
              });
              if (widget.onDateSelected != null) {
                widget.onDateSelected!(selectedDay);
              }
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
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
              markerDecoration: BoxDecoration(shape: BoxShape.circle),
              markersMaxCount: 4,
            ),
            calendarBuilders: CalendarBuilders(
              // ✅ 일정 마커 커스터마이징 (카테고리별 dot + +n 표시)
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();

                // 최대 3개까지만 표시
                final displayedEvents = events.take(3).toList();
                final remaining = events.length - displayedEvents.length;

                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 카테고리별 dot 표시
                      ...displayedEvents.map((event) {
                        Color color;

                        // event가 dynamic일 수 있으니 Map<String, dynamic>으로 캐스팅 후 접근
                        final Map<String, dynamic> e =
                            event as Map<String, dynamic>;

                        // category가 null일 경우 '기타'로 기본 처리
                        final String category = e['category'] ?? '기타';

                        switch (category) {
                          case '시험':
                            color = Colors.lightBlue;
                            break;
                          case '과제':
                            color = Colors.red;
                            break;
                          case '팀플':
                            color = Colors.purple;
                            break;
                          case '기타':
                            color = Colors.green;
                            break;
                          default:
                            color = Colors.grey;
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),

                      // 일정이 많을 경우 +n 표시
                      if (remaining > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            '+$remaining',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
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
            Text(
              '${_selectedDay?.toLocal().toIso8601String().substring(0, 10)} 일정이 없습니다.',
            )
          else
            ..._selectedEvents.map(
              (event) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide.none,
                ),
                child: ListTile(
                  title: Text(event['title'] ?? '제목 없음'),
                  subtitle: Text(
                    '${event['category'] ?? ''} · ${event['subject'] ?? ''}',
                  ),
                  trailing: _buildDdayTag(event),
                  onTap: () => _showEventDetailDialog(event),
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

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
