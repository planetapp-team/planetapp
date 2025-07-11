// 로그인 상태를 감지하고 로그인 여부에 따라 화면 분기 처리하는 위젯
// auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_test_page.dart';
import 'home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          // 로그인 되어 있으면 홈 페이지로 이동
          return HomePage(); // const 제거
        }
        // 로그인 안 되어 있으면 로그인/회원가입 화면 표시
        return const AuthTestPage();
      },
    );
  }
}
