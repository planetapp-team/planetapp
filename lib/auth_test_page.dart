// lib/auth_test_page.dart
// 기능: Firebase Auth + Firestore를 활용한 로그인 / 회원가입 화면
// ✅ 로그인 & 회원가입을 하나의 화면에서 처리 (isLogin bool 상태 토글)
// ✅ 회원가입 시 닉네임 추가 입력 및 Firestore에 저장
// ✅ 로그인 성공/회원가입 성공 시 홈화면('/home')으로 이동
// ✅ 오류 발생 시 SnackBar로 피드백 표시

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthTestPage extends StatefulWidget {
  const AuthTestPage({super.key});

  @override
  State<AuthTestPage> createState() => _AuthTestPageState();
}

class _AuthTestPageState extends State<AuthTestPage> {
  // 사용자 입력 컨트롤러
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nicknameController = TextEditingController(); // 회원가입 시 닉네임

  // true = 로그인 모드 / false = 회원가입 모드
  bool isLogin = true;

  @override
  void dispose() {
    // 메모리 누수 방지: 페이지 종료 시 컨트롤러 해제
    emailController.dispose();
    passwordController.dispose();
    nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? '로그인' : '회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 회원가입 모드일 때만 닉네임 입력 필드 표시
            if (!isLogin)
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: '닉네임'),
              ),
            // 이메일 입력 필드
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
            ),
            // 비밀번호 입력 필드
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            const SizedBox(height: 20),

            // 로그인 or 회원가입 버튼
            ElevatedButton(
              onPressed: isLogin ? signIn : signUp,
              child: Text(isLogin ? '로그인' : '회원가입'),
            ),

            // 로그인/회원가입 모드 토글 버튼
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? '회원가입 하기' : '이미 계정이 있나요? 로그인'),
            ),
          ],
        ),
      ),
    );
  }

  /// 회원가입 처리 함수
  Future<void> signUp() async {
    try {
      final nickname = nicknameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // 닉네임 입력 여부 확인
      if (nickname.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('닉네임을 입력하세요')));
        return;
      }

      // 이메일/비밀번호 입력 확인
      if (email.isEmpty || password.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요')));
        return;
      }

      // Firebase Auth로 계정 생성
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 생성된 사용자에 닉네임 설정
      await credential.user?.updateDisplayName(nickname);
      await credential.user?.reload();

      final updatedUser = FirebaseAuth.instance.currentUser;

      // Firestore에 사용자 정보 저장 (users 컬렉션)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser!.uid)
          .set({
            'nickname': nickname,
            'email': updatedUser.email,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      // 홈 화면으로 이동
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // 오류 발생 시 콘솔 출력 + 사용자에게 SnackBar 알림
      debugPrint('회원가입 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('회원가입 실패: $e')));
    }
  }

  /// 로그인 처리 함수
  Future<void> signIn() async {
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // 이메일/비밀번호 입력 여부 확인
      if (email.isEmpty || password.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요')));
        return;
      }

      // Firebase Auth 로그인 시도
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      // 홈 화면으로 이동
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // 로그인 실패 시 SnackBar로 알림
      debugPrint('로그인 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    }
  }
}
