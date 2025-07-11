//filter_page.dart
// 로그인괸 사용자 할일에서
// 선택된 과목 + 선택된 카테고리에 따라
// Firestore 쿼리 수행 후 리스트로 결과 출력
// lib/filter_page.dart
//filter_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  String? selectedSubject;
  List<String> selectedCategories = [];

  List<String> subjects = ['모든 과목']; // 기본 과목

  final List<String> categories = ['시험', '과제', '팀플', '기타'];

  List<Map<String, dynamic>> filteredTodos = [];

  @override
  void initState() {
    super.initState();
    loadSubjectsFromFirestore();
  }

  Future<void> loadSubjectsFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('todos').doc(uid);
    final querySnapshot = await userDocRef.collection('userTodos').get();

    final fetchedSubjects = querySnapshot.docs
        .map((doc) => (doc.data()['subject'] as String?))
        .where((subject) => subject != null && subject.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    setState(() {
      subjects = ['모든 과목', ...fetchedSubjects];
      selectedSubject = '모든 과목';
    });
  }

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
      data['id'] = doc.id; // 문서 ID 저장
      return data;
    }).toList();

    setState(() {
      filteredTodos = docs;
    });
  }

  void showEditCategoryDialog(Map<String, dynamic> todo) {
    String selected = todo['category'] ?? '기타';
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
                  TextField(
                    controller: newCategoryController,
                    decoration: const InputDecoration(
                      labelText: '새 카테고리 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      final newCat = newCategoryController.text.trim();
                      if (newCat.isEmpty) return;

                      // 중복 체크
                      if (!categories.contains(newCat)) {
                        setStateDialog(() {
                          categories.add(newCat);
                          selected = newCat;
                          newCategoryController.clear();
                        });
                      } else {
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

                    final todoRef = FirebaseFirestore.instance
                        .collection('todos')
                        .doc(uid)
                        .collection('userTodos')
                        .doc(todoId);

                    await todoRef.update({'category': selected});

                    applyFilters(); // 필터 결과 새로고침
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
            Center(
              child: ElevatedButton(
                onPressed: applyFilters,
                child: const Text('필터 적용'),
              ),
            ),
            const Divider(height: 32),
            const Text('필터 결과', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...filteredTodos.map((todo) {
              return Card(
                child: ListTile(
                  title: Text(todo['title'] ?? '제목 없음'),
                  subtitle: Text(
                    '과목: ${todo['subject'] ?? '없음'} / 카테고리: ${todo['category'] ?? '없음'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () => showEditCategoryDialog(todo),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
