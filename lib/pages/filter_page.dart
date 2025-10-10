// filter_page.dart

// 저장된 일정을 날짜(시작일/마감일), 과목, 카테고리로 검색 가능
// 날짜: 00월 00일 형식 (예: 9월 11일 ~ 9월 17일)
// 과목: 드롭다운, 하나 선택 가능
// 카테고리: 체크박스, 복수 선택 가능
// 날짜/과목/카테고리 중 하나만 선택해도 검색 가능

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  String? selectedSubject;
  List<String> selectedCategories = [];
  List<String> subjects = [];
  final List<String> defaultCategories = ['시험', '과제', '팀플', '기타'];
  List<String> userCategories = [];
  DateTimeRange? selectedDateRange;
  List<Map<String, dynamic>> filteredTodos = [];
  bool showSelectConditionMessage = false;

  List<String> get categories => [...defaultCategories, ...userCategories];

  @override
  void initState() {
    super.initState();
    loadSubjectsFromFirestore();
    loadUserCategoriesFromFirestore();
  }

  Future<void> loadSubjectsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('todos').doc(uid);
    final querySnapshot = await userDocRef.collection('userTodos').get();

    final fetchedSubjects = querySnapshot.docs
        .map((doc) => (doc.data()['subject'] as String?))
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    setState(() {
      subjects = fetchedSubjects;
      selectedSubject = null;
    });
  }

  Future<void> loadUserCategoriesFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await userDocRef.get();
    final List<dynamic>? fetched = snapshot.data()?['userCategories'];

    setState(() {
      userCategories = fetched != null ? List<String>.from(fetched) : [];
    });
  }

  void applyFilters() async {
    if (selectedSubject == null &&
        selectedCategories.isEmpty &&
        selectedDateRange == null) {
      setState(() {
        showSelectConditionMessage = true;
        filteredTodos = [];
      });
      return;
    }

    setState(() {
      showSelectConditionMessage = false;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('todos').doc(uid);
    Query query = userDocRef.collection('userTodos');

    if (selectedSubject != null) {
      query = query.where('subject', isEqualTo: selectedSubject);
    }
    if (selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: selectedCategories);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['docId'] = doc.id;
      return data;
    }).toList();

    final filteredByDate = selectedDateRange != null
        ? docs.where((todo) {
            final startDateTimestamp = todo['startDate'];
            final endDateTimestamp = todo['endDate'];

            if (startDateTimestamp == null && endDateTimestamp == null)
              return false;

            final startDate = startDateTimestamp != null
                ? (startDateTimestamp as Timestamp).toDate()
                : (endDateTimestamp as Timestamp).toDate();
            final endDate = endDateTimestamp != null
                ? (endDateTimestamp as Timestamp).toDate()
                : startDate;

            final todoStart = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            final todoEnd = DateTime(endDate.year, endDate.month, endDate.day);

            final filterStart = DateTime(
              selectedDateRange!.start.year,
              selectedDateRange!.start.month,
              selectedDateRange!.start.day,
            );
            final filterEnd = DateTime(
              selectedDateRange!.end.year,
              selectedDateRange!.end.month,
              selectedDateRange!.end.day,
            );

            return todoEnd.isAfter(
                  filterStart.subtract(const Duration(days: 1)),
                ) &&
                todoStart.isBefore(filterEnd.add(const Duration(days: 1)));
          }).toList()
        : docs;

    setState(() {
      filteredTodos = filteredByDate;
    });
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return "${date.month}월 ${date.day}일";
    } else if (timestamp is DateTime) {
      final date = timestamp;
      return "${date.month}월 ${date.day}일";
    } else {
      return '-';
    }
  }

  void resetFilters() {
    setState(() {
      selectedDateRange = null;
      selectedSubject = null;
      selectedCategories.clear();
      filteredTodos = [];
      showSelectConditionMessage = false;
    });
  }

  Future<void> deleteTodoAndRefresh(Map<String, dynamic> todo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docId = todo['docId'];
    if (docId == null) return;

    await FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .doc(docId)
        .delete();

    applyFilters();
  }

  Color getSubjectColor(String subject) {
    final hash = subject.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.6).toColor();
  }

  Widget _buildDdayTag(Map<String, dynamic> todo) {
    if (todo['startDate'] == null) return const SizedBox.shrink();
    final dynamic tsDynamic = todo['startDate'];
    if (tsDynamic is! Timestamp) return const SizedBox.shrink();

    final DateTime date = tsDynamic.toDate();
    final DateTime now = DateTime.now();

    final DateTime dateOnly = DateTime(date.year, date.month, date.day);
    final DateTime nowOnly = DateTime(now.year, now.month, now.day);
    final int difference = dateOnly.difference(nowOnly).inDays;

    if (difference == 0) {
      return const Text(
        'D-Day',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    } else if (difference > 0) {
      return Text(
        'D-$difference',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      return const Text(
        '종료',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일정 필터')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('날짜', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final today = DateTime.now();
                final firstDate = DateTime(2025, 1, 1);
                final lastDate = DateTime(3000, 12, 31);

                final pickedRange = await showDateRangePicker(
                  context: context,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  initialDateRange:
                      selectedDateRange ??
                      DateTimeRange(start: today, end: today),
                  helpText: '기간을 입력하세요.',
                  cancelText: '취소', // cancle-> 취소 버튼 변경
                  confirmText: '확인', // ok -> 확인 버튼 변경
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.yellow,
                          onPrimary: AppColors.black,
                          surface: AppColors.white,
                          onSurface: AppColors.black,
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.black,
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (pickedRange != null) {
                  setState(() {
                    selectedDateRange = DateTimeRange(
                      start: pickedRange.start,
                      end: pickedRange.end,
                    );
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gray2),
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedDateRange != null
                          ? "${selectedDateRange!.start.month}월 ${selectedDateRange!.start.day}일 ~ ${selectedDateRange!.end.month}월 ${selectedDateRange!.end.day}일"
                          : '기간을 선택하세요',
                      style: TextStyle(
                        fontSize: 16,
                        color: selectedDateRange != null
                            ? AppColors.black
                            : AppColors.gray2,
                      ),
                    ),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('과목', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedSubject,
              isExpanded: true,
              hint: const Text('과목을 선택해주세요.'),
              items: subjects
                  .map(
                    (subject) => DropdownMenuItem<String>(
                      value: subject,
                      child: Text(subject),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubject = value;
                });
              },
              dropdownColor: AppColors.white,
            ),
            const SizedBox(height: 20),
            const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 60,
              runSpacing: 50,
              children: [
                ...defaultCategories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat),
                        Checkbox(
                          value: selectedCategories.contains(cat),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedCategories.add(cat);
                              } else {
                                selectedCategories.remove(cat);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                ...userCategories.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat),
                        Checkbox(
                          value: selectedCategories.contains(cat),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedCategories.add(cat);
                              } else {
                                selectedCategories.remove(cat);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: resetFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gray2,
                    foregroundColor: AppColors.black,
                    minimumSize: const Size(100, 40),
                  ),
                  child: const Text(
                    '초기화',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 13),
                ElevatedButton(
                  onPressed: applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.black,
                    minimumSize: const Size(100, 40),
                  ),
                  child: const Text(
                    '검색',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (showSelectConditionMessage)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  '조건을 선택해 주세요.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),
            const Text('필터 결과', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            filteredTodos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        '일치하는 일정이 없습니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: filteredTodos.map((todo) {
                      final subject = todo['subject'] ?? '기타';
                      final Color subjectColor = getSubjectColor(subject);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 0,
                        ),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${todo['subject'] ?? ''}/${todo['category'] ?? ''}/${todo['title'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildDdayTag(todo),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
