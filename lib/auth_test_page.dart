//기능:
// 로그인.회원가입 토클
//회원가입 시 닉네임 입력
// Firebase Auth 연동
// Firestore 사용자 정보 저장
// 로그인 및 회원가입을 하나의 화면에서 처리하는 UI
// Firestore에 닉네임 저장, Firebase Auth 연동 포함
// lib/auth_test_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthTestPage extends StatefulWidget {
  const AuthTestPage({super.key});

  @override
  State<AuthTestPage> createState() => _AuthTestPageState();
}

class _AuthTestPageState extends State<AuthTestPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nicknameController = TextEditingController(); // 회원가입 시 닉네임 입력용

  bool isLogin = true; // true = 로그인 모드, false = 회원가입 모드

  @override
  void dispose() {
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
            // ✅ 회원가입 모드일 때만 닉네임 입력
            if (!isLogin)
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: '닉네임'),
              ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: '이메일'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            const SizedBox(height: 20),
            // ✅ 로그인/회원가입 버튼
            ElevatedButton(
              onPressed: isLogin ? signIn : signUp,
              child: Text(isLogin ? '로그인' : '회원가입'),
            ),
            // ✅ 로그인/회원가입 모드 전환 버튼
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? '회원가입 하기' : '이미 계정이 있나요? 로그인'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 회원가입 함수: Firebase Auth + Firestore 연동
  Future<void> signUp() async {
    try {
      final nickname = nicknameController.text.trim();
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      // 입력 검증
      if (nickname.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('닉네임을 입력하세요')));
        return;
      }
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요')));
        return;
      }

      // 🔐 Firebase Auth 계정 생성
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // ✨ Firebase Auth 프로필에 닉네임 저장
      await credential.user?.updateDisplayName(nickname);
      await credential.user?.reload();

      final updatedUser = FirebaseAuth.instance.currentUser;

      // 📝 Firestore에 사용자 정보 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser!.uid)
          .set({
            'nickname': nickname,
            'email': updatedUser.email,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home'); // 홈 화면으로 이동
      }
    } catch (e) {
      print('회원가입 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('회원가입 실패: $e')));
      }
    }
  }

  // ✅ 로그인 함수: Firebase Auth 사용
  Future<void> signIn() async {
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요')));
        return;
      }

      // 🔐 Firebase Auth 로그인
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home'); // 홈 화면으로 이동
      }
    } catch (e) {
      print('로그인 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
      }
    }
  }
}
