// lib/auth_test_page.dart
// 로그인 화면과 회원가입 화면
// 로그인 화면 : 아이디 입력/ 비밀번호 입력(로그인, 회원가입 버튼)
// 회원가입 화면: 닉네임, 아이디, 비밀번호, 비밀번호 확인(확인 버튼)
// 로그인 화면 버튼 고정 크기 w120*h35 dp 적용
// 회원가입 화면 입력 필드 - 확인 버튼 간격 조정
// 필수 항목 미작성 시 경고 문구 표시
// 오류 메시지 색상 적용 (AppColors.red)
// 회원가입 왼쪽 상단에 뒤로가기 버튼 추가

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/theme.dart';

class AuthTestPage extends StatefulWidget {
  const AuthTestPage({super.key});

  @override
  State<AuthTestPage> createState() => _AuthTestPageState();
}

class _AuthTestPageState extends State<AuthTestPage> {
  final idController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nicknameController = TextEditingController();
  final birthController = TextEditingController();
  final recoveryEmailController = TextEditingController();

  bool isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? idError;
  String? passwordError;
  String? confirmPasswordError;
  String? nicknameError;
  String? recoveryEmailError;
  String? loginError;
  bool showRequiredFieldsWarning = false; // 필수 항목 경고 표시용

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nicknameController.dispose();
    birthController.dispose();
    recoveryEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: isLogin
          ? AppBar(title: const SizedBox.shrink())
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    isLogin = true;
                    _clearErrors();
                    showRequiredFieldsWarning = false;
                  });
                },
              ),
              title: const Text(
                '회원가입',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              centerTitle: false,
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 회원가입 필드
            if (!isLogin) _buildSignupFields(),
            if (!isLogin) const SizedBox(height: 100), // 회원가입 입력 필드-버튼 간격
            // 필수 항목 미작성 시 경고 문구
            if (!isLogin && showRequiredFieldsWarning)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: Text(
                    '필수 항목을 모두 작성해주세요',
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
                ),
              ),
            // 로그인 화면 필드
            if (isLogin) _buildLoginFields(),
            SizedBox(height: isLogin ? 20 : 0), // 로그인 화면 간격
            Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    height: 35,
                    child: ElevatedButton(
                      onPressed: isLogin
                          ? signIn
                          : () {
                              // 필수 항목 미작성 체크
                              if (nicknameController.text.isEmpty ||
                                  idController.text.isEmpty ||
                                  passwordController.text.isEmpty ||
                                  confirmPasswordController.text.isEmpty) {
                                setState(() {
                                  showRequiredFieldsWarning = true;
                                });
                              } else {
                                setState(() {
                                  showRequiredFieldsWarning = false;
                                });
                                signUp();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        isLogin ? '로그인' : '확인',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.black,
                          fontWeight: FontWeight.bold, // <- bold 적용
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  if (isLogin)
                    SizedBox(
                      width: 120,
                      height: 35,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isLogin = false;
                            _clearErrors();
                            loginError = null;
                            showRequiredFieldsWarning = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.yellow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.black,
                            fontWeight: FontWeight.bold, // <- bold 적용
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text(
              '* 필수항목',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: nicknameController,
          decoration: InputDecoration(
            label: _buildLabelWithStar('닉네임'),
            errorText: nicknameError,
            errorStyle: const TextStyle(color: AppColors.red),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: idController,
          decoration: InputDecoration(
            label: _buildLabelWithStar('아이디'),
            hintText: '6자 이상 영문 또는 영문+숫자',
            errorText: idError,
            errorStyle: const TextStyle(color: AppColors.red),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            label: _buildLabelWithStar('비밀번호'),
            hintText: '8자 이상 영문+숫자 포함',
            errorText: passwordError,
            errorStyle: const TextStyle(color: AppColors.red),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            label: _buildLabelWithStar('비밀번호 확인'),
            hintText: '비밀번호를 한번 더 입력해주세요.',
            errorText: confirmPasswordError,
            errorStyle: const TextStyle(color: AppColors.red),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Center(
          child: Text(
            '캠비',
            style: AppTextStyles.title.copyWith(
              fontSize: 48,
              color: AppColors.darkBrown,
            ),
          ),
        ),
        const SizedBox(height: 60),
        TextField(
          controller: idController,
          decoration: InputDecoration(
            labelText: '아이디 입력',
            errorText: idError,
            errorStyle: const TextStyle(color: AppColors.red),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: '비밀번호 입력',
            errorText: passwordError,
            errorStyle: const TextStyle(color: AppColors.red),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 40),
        if (loginError != null)
          Center(
            child: Text(
              loginError!,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabelWithStar(String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(color: AppColors.black, fontSize: 16),
          ),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.red, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _clearErrors() {
    idError = passwordError = confirmPasswordError = nicknameError =
        recoveryEmailError = null;
    loginError = null;
    showRequiredFieldsWarning = false;
  }

  Future<void> signUp() async {
    final nickname = nicknameController.text.trim();
    final id = idController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    _clearErrors();
    bool hasError = false;

    if (nickname.isEmpty) {
      nicknameError = '닉네임을 입력하세요';
      hasError = true;
    }
    if (id.isEmpty) {
      idError = '아이디를 입력하세요';
      hasError = true;
    } else if (!RegExp(r'^[a-zA-Z]{6,}[0-9]*$').hasMatch(id)) {
      idError = '6자 이상 영문 또는 영문+숫자 조합';
      hasError = true;
    }
    if (password.isEmpty) {
      passwordError = '비밀번호를 입력하세요';
      hasError = true;
    } else if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$',
    ).hasMatch(password)) {
      passwordError = '8자 이상 영문+숫자 포함';
      hasError = true;
    }
    if (confirmPassword.isEmpty) {
      confirmPasswordError = '비밀번호를 한번 더 입력해주세요.';
      hasError = true;
    } else if (password != confirmPassword) {
      confirmPasswordError = '비밀번호가 일치하지 않습니다';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    try {
      final idExists = await FirebaseFirestore.instance
          .collection('users')
          .where('emailId', isEqualTo: id)
          .get();
      if (idExists.docs.isNotEmpty) {
        setState(() {
          idError = '사용중인 아이디입니다';
        });
        return;
      }

      final nicknameExists = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .get();
      if (nicknameExists.docs.isNotEmpty) {
        setState(() {
          nicknameError = '사용중인 닉네임입니다';
        });
        return;
      }

      final emailForFirebase = '$id@myapp.com';
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailForFirebase,
            password: password,
          );

      await credential.user?.updateDisplayName(nickname);
      await credential.user?.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      final fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser!.uid)
          .set({
            'nickname': nickname,
            'email': emailForFirebase,
            'emailId': id,
            'createdAt': FieldValue.serverTimestamp(),
            'fcm_token': fcmToken,
            'last_updated': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      showSnackBar('회원가입 실패: $e');
    }
  }

  Future<void> signIn() async {
    final inputId = idController.text.trim();
    final password = passwordController.text.trim();

    _clearErrors();
    bool hasError = false;

    if (inputId.isEmpty) {
      idError = '아이디를 입력하세요';
      hasError = true;
    }
    if (password.isEmpty) {
      passwordError = '비밀번호를 입력하세요';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    try {
      final emailToUse = '$inputId@myapp.com';
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        loginError = '아이디 또는 비밀번호가 잘못되었습니다.';
      });
    }
  }

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
