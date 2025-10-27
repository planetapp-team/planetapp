// lib/todo_service.dart
// Firestore에 할 일 저장 / 조회 / 수정 / 삭제 기능 포함
// 자동 분류(category_classifier.dart) 기반 카테고리 분류
// 오늘 일정만 가져오는 필터링 기능 (홈화면 전용)
// 일정 등록 시 시작일/마감일 변환 및 자동 카테고리 분류
// 일정 수정 시 날짜 및 제목 변경 감지

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'category_classifier.dart'; // 제목 기반 자동 분류 함수

class TodoService {
  // 🔷 [읽기] 실시간으로 유저의 할 일 목록을 가져오는 스트림 (최신순)
  static Stream<QuerySnapshot> getTodoStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .orderBy('createdAt', descending: true) // 최신순 정렬
        .snapshots(); // 실시간 스트림 반환
  }

  // 🔷 [수정] 특정 일정(docId)을 수정 (title 변경 시 자동 분류 재적용)
  static Future<void> updateTodo(
    String docId,
    Map<String, dynamic> updatedData,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // ✅ title이 수정되었고, category가 없다면 자동 분류 적용
    if (updatedData.containsKey('title') &&
        !updatedData.containsKey('category')) {
      updatedData['category'] = classifyCategory(updatedData['title'] ?? '');
    }

    // ✅ 날짜 타입이 DateTime이라면 Timestamp로 변환
    if (updatedData.containsKey('startDate') ||
        updatedData.containsKey('endDate')) {
      if (updatedData['startDate'] is DateTime) {
        updatedData['startDate'] = Timestamp.fromDate(updatedData['startDate']);
      }
      if (updatedData['endDate'] is DateTime) {
        updatedData['endDate'] = Timestamp.fromDate(updatedData['endDate']);
      }
    }

    // ✅ Firestore 문서 참조 후 업데이트
    final docRef = FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .doc(docId);

    await docRef.update(updatedData);
  }

  // 🔷 [삭제] 특정 일정(docId)을 Firestore에서 삭제
  static Future<void> deleteTodo(String docId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .doc(docId);

    await docRef.delete();
  }

  // 🔷 [추가] 새 일정을 Firestore에 저장
  static Future<void> addTodo(Map<String, dynamic> todoData) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // ✅ 날짜(DateTime)를 Firestore용 Timestamp로 변환
    if (todoData['startDate'] is DateTime) {
      todoData['startDate'] = Timestamp.fromDate(todoData['startDate']);
    }
    if (todoData['endDate'] is DateTime) {
      todoData['endDate'] = Timestamp.fromDate(todoData['endDate']);
    }

    // ✅ title이 있다면 자동 분류(category) 적용
    if (todoData.containsKey('title')) {
      todoData['category'] = classifyCategory(todoData['title'] ?? '');
    }

    // ✅ 사용자별 하위 컬렉션에 추가
    final docRef = FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos');

    await docRef.add(todoData);
  }

  // 🔷 [필터 조회] 오늘의 일정만 실시간으로 가져오는 스트림 (홈 화면 전용)
  static Stream<QuerySnapshot> getTodayTodos() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 오늘 시작 ~ 오늘 끝 범위 설정
    final todayStart = DateTime.now().subtract(Duration(hours: 24));
    final todayEnd = DateTime.now().add(Duration(hours: 24));

    return FirebaseFirestore.instance
        .collection('todos')
        .doc(uid)
        .collection('userTodos')
        .where(
          'startDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
        )
        .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
        .snapshots();
  }
}
