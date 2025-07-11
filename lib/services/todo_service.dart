// todo_service.dart
// Firestore에 할 일 저장/조회/수정/삭제 + 자동 분류 기능 포함

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'category_classifier.dart'; // 🔥 자동 분류 함수 가져오기

class TodoService {
  // ✅ 할 일 추가 (subject 포함)
  static Future<void> addTodo(
    String title,
    String subject,
    DateTime dueDate,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final category = classifyCategory(title); // 🔥 자동 분류

    final todosRef = FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos');

    await todosRef.add({
      'title': title,
      'subject': subject, // ✅ 과목 저장
      'category': category,
      'dueDate': Timestamp.fromDate(dueDate),
      'isDone': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ 할 일 목록 가져오기 (스트림)
  static Stream<QuerySnapshot> getTodoStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ✅ 할 일 업데이트
  static Future<void> updateTodo(
    String docId,
    Map<String, dynamic> updatedData,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 제목이 바뀌면 category도 재분류
    if (updatedData.containsKey('title')) {
      updatedData['category'] = classifyCategory(updatedData['title'] ?? '');
    }

    final docRef = FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .doc(docId);

    await docRef.update(updatedData);
  }

  // ✅ 할 일 삭제
  static Future<void> deleteTodo(String docId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .doc(docId);

    await docRef.delete();
  }
}
