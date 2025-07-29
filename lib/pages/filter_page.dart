// filter_page.dart
// 로그인한 사용자의 할 일 목록에서
// 선택한 과목과 카테고리에 따라 Firestore 쿼리를 수행하여
// 필터된 결과를 리스트로 출력하는 화면
//
// 카테고리: 시험 / 과제 / 팀플 / 기타 (기본 카테고리 고정)
// 사용자 추가 카테고리 관리 (추가/수정/삭제 가능)
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
  final List<String> defaultCategories = // 기본 카테고리 (삭제/수정 불가)
  [
    '시험',
    '과제',
    '팀플',
    '기타',
  ];
  List<String> userCategories = []; // 사용자 추가 카테고리 (추가/수정/삭제 가능)

  // 전체 카테고리 = 기본 + 사용자 추가
  List<String> get categories => [...defaultCategories, ...userCategories];

  List<Map<String, dynamic>> filteredTodos = []; // 필터링된 할 일 데이터 리스트

  @override
  void initState() {
    super.initState();
    loadSubjectsFromFirestore(); // 과목 불러오기
    loadUserCategoriesFromFirestore(); // 사용자 카테고리 불러오기
  }

  // Firestore에서 사용자 과목 조회하여 subjects 업데이트
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
      subjects = ['모든 과목', ...fetchedSubjects];
      selectedSubject = '모든 과목';
    });
  }

  // Firestore에서 사용자 추가 카테고리 불러오기
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

  // Firestore에 userCategories 저장
  Future<void> saveUserCategoriesToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userDocRef.set({
      'userCategories': userCategories,
    }, SetOptions(merge: true));
  }

  // 필터 적용하여 Firestore 쿼리 실행 및 결과 갱신
  void applyFilters() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDocRef = FirebaseFirestore.instance.collection('todos').doc(uid);
    Query query = userDocRef.collection('userTodos');

    if (selectedSubject != null && selectedSubject != '모든 과목') {
      query = query.where('subject', isEqualTo: selectedSubject);
    }
    if (selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: selectedCategories);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    setState(() {
      filteredTodos = docs;
    });
  }

  // 카테고리 수정/추가 다이얼로그 (항상 최신 categories 사용)
  void showEditCategoryDialog(Map<String, dynamic> todo) {
    String selected = todo['category'] ?? defaultCategories.first;
    final newCategoryController = TextEditingController();

    // 매번 최신 리스트 생성 및 중복 제거
    List<String> currentCategories = categories.toSet().toList();
    if (!currentCategories.contains(selected)) {
      selected = currentCategories.first;
    }

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
                    items: currentCategories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // 새 카테고리 입력 및 추가
                  TextField(
                    controller: newCategoryController,
                    decoration: const InputDecoration(
                      labelText: '새 카테고리 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final newCat = newCategoryController.text.trim();
                      if (newCat.isEmpty) return;
                      if (!currentCategories.contains(newCat)) {
                        setStateDialog(() {
                          userCategories.add(newCat);
                          selected = newCat;
                          currentCategories = categories.toSet().toList();
                        });
                        await saveUserCategoriesToFirestore();
                      } else {
                        setStateDialog(() {
                          selected = newCat;
                        });
                      }
                      newCategoryController.clear();
                    },
                    child: const Text('추가'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    final todoId = todo['id'];
                    if (todoId == null) return;

                    await FirebaseFirestore.instance
                        .collection('todos')
                        .doc(uid)
                        .collection('userTodos')
                        .doc(todoId)
                        .update({'category': selected});

                    applyFilters();
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

  // 사용자 추가 카테고리 삭제 다이얼로그
  void showDeleteCategoryDialog(String category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('카테고리 삭제 확인'),
          content: Text('카테고리 "\$category"를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                userCategories.remove(category);
                await saveUserCategoriesToFirestore();
                setState(() {});
              },
              child: const Text('삭제'),
            ),
          ],
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
            // 과목 선택 드롭다운
            const Text('과목 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedSubject,
              isExpanded: true,
              items: subjects.map((subject) {
                return DropdownMenuItem(value: subject, child: Text(subject));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubject = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // 카테고리 선택 체크박스
            const Text(
              '카테고리 선택',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Column(
              children: [
                // 기본 카테고리 (삭제/수정 불가)
                ...defaultCategories.map((cat) {
                  return CheckboxListTile(
                    title: Text(cat),
                    value: selectedCategories.contains(cat),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true)
                          selectedCategories.add(cat);
                        else
                          selectedCategories.remove(cat);
                      });
                    },
                  );
                }),
                const Divider(),
                // 사용자 추가 카테고리 (삭제 가능)
                ...userCategories.map((cat) {
                  return CheckboxListTile(
                    title: Text(cat),
                    value: selectedCategories.contains(cat),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true)
                          selectedCategories.add(cat);
                        else
                          selectedCategories.remove(cat);
                      });
                    },
                    secondary: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => showDeleteCategoryDialog(cat),
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: applyFilters,
                child: const Text('필터 적용'),
              ),
            ),

            const Divider(height: 32),
            const Text('필터 결과', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // 필터 결과 리스트
            filteredTodos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        '저장된 일정이 없습니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : Column(
                    children: filteredTodos.map((todo) {
                      return Card(
                        child: ListTile(
                          title: Text(todo['title'] ?? '제목 없음'),
                          subtitle: Text(
                            "과목: ${todo['subject'] ?? '없음'} / 카테고리: ${todo['category'] ?? '없음'}",
                          ),
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
