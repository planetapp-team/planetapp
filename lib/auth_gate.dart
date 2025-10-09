// lib/auth_gate.dart
// 기능: Firebase Auth 로그인 상태 감지 후 자동 분기 처리
// 로그인 상태이면 -> HomePage로 이동
// 로그인 상태 아니면 -> AuthTestPage(로그인/회원가입 페이지)로 이동
// 로그인/회원가입 성공 시 자동으로 홈으로 이동 (FirebaseAuth 상태 스트림 활용)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_test_page.dart'; // 로그인/회원가입 UI 페이지
import 'home_page.dart'; // 로그인 성공 후 이동할 홈 화면

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebase Auth의 로그인 상태 변경 스트림 수신
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 연결 상태가 아직 준비 중이면 로딩 표시
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 로그인 되어 있으면 HomePage로 이동
        if (snapshot.hasData) {
          return HomePage(); // 로그인한 유저 존재 -> 홈 화면으로 이동
        }

        // 로그인 안 되어 있으면 AuthTestPage(로그인/회원가입 화면)로 이동
        return const AuthTestPage();
      },
    );
  }
}
