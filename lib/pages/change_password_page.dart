// change_password_page.dart
// 비밀번호 변경 페이지 UI 및 Firebase 비밀번호 변경 기능 구현

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final currentPasswordController = TextEditingController(); // 현재 비밀번호 입력 컨트롤러
  final newPasswordController = TextEditingController(); // 새 비밀번호 입력 컨트롤러

  // 비밀번호 변경 함수
  Future<void> changePassword() async {
    final user = FirebaseAuth.instance.currentUser!;
    final cred = EmailAuthProvider.credential(
      email: user.email!, // 현재 사용자 이메일
      password: currentPasswordController.text, // 입력한 현재 비밀번호
    );

    try {
      // 현재 비밀번호로 재인증 수행 (보안상 필요)
      await user.reauthenticateWithCredential(cred);
      // 새 비밀번호로 업데이트
      await user.updatePassword(newPasswordController.text);

      // 변경 성공 메시지 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었습니다.')));

      Navigator.pop(context); // 이전 화면으로 이동
    } catch (e) {
      // 에러 발생 시 에러 메시지 표시
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 현재 비밀번호 입력 필드
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(labelText: '현재 비밀번호'),
              obscureText: true, // 입력 내용 숨김 처리
            ),
            // 새 비밀번호 입력 필드
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: '새 비밀번호'),
              obscureText: true, // 입력 내용 숨김 처리
            ),
            const SizedBox(height: 20),
            // 변경 버튼, 눌렀을 때 changePassword 함수 호출
            ElevatedButton(
              onPressed: changePassword,
              child: const Text('변경하기'),
            ),
          ],
        ),
      ),
    );
  }
}
