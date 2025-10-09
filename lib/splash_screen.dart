// splash_screen.dart
// 처음 앱 실행 시 로딩이 되는 화면
// 나만의 캠퍼스 비서, 캠비 + 아이콘 화면으로 넘어가면서 이동
// 로그인/회원가입 화면으로 이동
// 디자인 담당자 -> 아이콘 위로, 문구 아래로 변경

import 'package:flutter/material.dart';
import 'auth_test_page.dart'; // 로그인/회원가입 화면
import 'utils/theme.dart'; // theme.dart import 추가

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  void _goNext() async {
    // 3초 동안 Splash 표시 후 로그인/회원가입 화면으로 이동
    await Future.delayed(const Duration(seconds: 3));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AuthTestPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.yellow, // theme.dart에서 정의한 배경색 사용
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  // 🔹 PNG 로고 (폰/태블릿에서 크게 보이도록 반응형 적용)
                  Image.asset(
                    'assets/app_icon/logo.png',
                    width:
                        MediaQuery.of(context).size.width * 0.5, // 화면 너비의 50%
                    height:
                        MediaQuery.of(context).size.height * 0.25, // 화면 높이의 25%
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20), // 아이콘과 문구 사이 간격 넉넉히
                  Text(
                    '나만의 캠퍼스 비서',
                    style: AppTextStyles
                        .catchphrase, // theme.dart에서 정의한 YClover Regular 25sp 적용
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8), // 문구 사이 간격 조금 넓힘
                  Text(
                    '캠비',
                    style: AppTextStyles
                        .title, // theme.dart에서 정의한 YClover Bold 70sp 적용
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
