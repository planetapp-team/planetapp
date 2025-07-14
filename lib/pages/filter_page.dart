// filter_page.dart
// 로그인한 사용자의 할 일 목록에서
// 선택한 과목과 카테고리에 따라 Firestore 쿼리를 수행하여
// 필터된 결과를 리스트로 출력하는 화면

// 카테고리: 시험 / 과제 / 팀플 / 기타
// 과목: 사용자가 입력한 모든 과목 목록에서 선택 가능

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'todo_test_page.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  String? selectedSubject; // 선택된 과목
  List<String> selectedCategories = []; // 선택된 카테고리들

  List<String> subjects = ['모든 과목']; // 과목 목록 (기본값 '모든 과목')
  final List<String> categories = ['시험', '과제', '팀플', '기타']; // 기본 카테고리

  List<Map<String, dynamic>> filteredTodos = []; // 필터링된 할 일 데이터 리스트

  @override
  void initState() {
    super.initState();
    loadSubjectsFromFirestore(); // Firestore에서 사용자 과목 불러오기
  }

  // Firestore에서 현재 사용자의 과목을 조회하여 목록에 추가
  Future<void> loadSubjectsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('todos').doc(uid);
    final querySnapshot = await userDocRef.collection('userTodos').get();

    // 각 문서에서 subject 필드 추출, null 또는 빈 문자열 제외, 중복 제거
    final fetchedSubjects = querySnapshot.docs
        .map((doc) => (doc.data()['subject'] as String?))
        .where((subject) => subject != null && subject.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    setState(() {
      // '모든 과목'을 앞에 추가하여 드롭다운 초기값 설정
      subjects = ['모든 과목', ...fetchedSubjects];
      selectedSubject = '모든 과목';
    });
  }

  // 선택된 과목과 카테고리로 Firestore 쿼리 실행 후 결과 갱신
  void applyFilters() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('todos').doc(uid);
    Query query = userDocRef.collection('userTodos');

    // 과목이 '모든 과목'이 아니면 조건 추가
    if (selectedSubject != null && selectedSubject != '모든 과목') {
      query = query.where('subject', isEqualTo: selectedSubject);
    }

    // 카테고리가 선택되었으면 whereIn 조건 추가
    if (selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: selectedCategories);
    }

    final snapshot = await query.get();

    // 문서 리스트를 Map으로 변환하며 id도 추가
    final docs = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    setState(() {
      filteredTodos = docs; // 필터 결과 갱신
    });
  }

  // 특정 할 일(todo)의 카테고리 수정 또는 새 카테고리 추가 다이얼로그
  void showEditCategoryDialog(Map<String, dynamic> todo) {
    String selected = todo['category'] ?? '기타'; // 현재 카테고리 선택
    final TextEditingController newCategoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('카테고리 수정 / 추가'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 기존 카테고리 선택 드롭다운
                  DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          selected = value;
                        });
                      }
                    },
                    items: categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  // 새 카테고리 입력 필드
                  TextField(
                    controller: newCategoryController,
                    decoration: const InputDecoration(
                      labelText: '새 카테고리 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 새 카테고리 추가 버튼
                  ElevatedButton(
                    onPressed: () {
                      final newCat = newCategoryController.text.trim();
                      if (newCat.isEmpty) return;

                      // 새 카테고리가 기존 목록에 없으면 추가
                      if (!categories.contains(newCat)) {
                        setStateDialog(() {
                          categories.add(newCat);
                          selected = newCat;
                          newCategoryController.clear();
                        });
                      } else {
                        // 이미 있으면 선택만 변경
                        setStateDialog(() {
                          selected = newCat;
                          newCategoryController.clear();
                        });
                      }
                    },
                    child: const Text('추가'),
                  ),
                ],
              ),
              actions: [
                // 취소 버튼
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                // 저장 버튼: Firestore 업데이트 후 필터 재적용
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;

                    final todoId = todo['id'];
                    if (todoId == null) return;

                    final todoRef = FirebaseFirestore.instance
                        .collection('todos')
                        .doc(uid)
                        .collection('userTodos')
                        .doc(todoId);

                    await todoRef.update({'category': selected});

                    applyFilters(); // 변경 후 필터 다시 적용하여 화면 갱신
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('필터된 할일 보기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 과목 선택 드롭다운 UI
            const Text('과목 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedSubject,
              hint: const Text('과목 선택'),
              isExpanded: true,
              items: subjects.map((subject) {
                return DropdownMenuItem<String>(
                  value: subject,
                  child: Text(subject),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubject = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // 카테고리 선택 체크박스 UI
            const Text(
              '카테고리 선택',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Column(
              children: categories.map((category) {
                return CheckboxListTile(
                  title: Text(category),
                  value: selectedCategories.contains(category),
                  onChanged: (bool? checked) {
                    setState(() {
                      if (checked == true) {
                        selectedCategories.add(category);
                      } else {
                        selectedCategories.remove(category);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            // 필터 적용 버튼
            Center(
              child: ElevatedButton(
                onPressed: applyFilters,
                child: const Text('필터 적용'),
              ),
            ),

            const Divider(height: 32),

            // 필터 결과 제목
            const Text('필터 결과', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // 필터된 할 일 리스트 출력
            filteredTodos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        '저장된 일정이 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: filteredTodos.map((todo) {
                      return Card(
                        child: ListTile(
                          title: Text(todo['title'] ?? '제목 없음'),
                          subtitle: Text(
                            '과목: ${todo['subject'] ?? '없음'} / 카테고리: ${todo['category'] ?? '없음'}',
                          ),
                          // 카테고리 수정 버튼
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            onPressed: () => showEditCategoryDialog(todo),
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
