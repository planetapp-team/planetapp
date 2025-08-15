// lib\pages\ForgotPasswordPage.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController recoveryEmailController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  String? idError;
  String? emailError;
  String? passwordError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    idController.dispose();
    recoveryEmailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 1️⃣ 코드 전송 확인 팝업
  void _showSendCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('입력한 메일로 인증 코드를 받으시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendVerificationCode();
            },
            child: const Text('코드 전송'),
          ),
        ],
      ),
    );
  }

  // 2️⃣ 사용자 조회 및 인증 코드 전송
  Future<void> _sendVerificationCode() async {
    final inputId = idController.text.trim();
    final inputEmail = recoveryEmailController.text.trim();

    setState(() {
      idError = null;
      emailError = null;
    });

    if (inputId.isEmpty) {
      setState(() => idError = '아이디를 입력하세요');
      return;
    }
    if (inputEmail.isEmpty) {
      setState(() => emailError = '이메일을 입력하세요');
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('emailId', isEqualTo: inputId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => idError = '존재하지 않는 회원정보입니다.');
        return;
      }

      final userData = query.docs.first.data();
      final savedEmail = userData['recoveryEmail'];

      if (savedEmail == null || savedEmail != inputEmail) {
        setState(() => emailError = '이메일이 일치하지 않습니다.');
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: savedEmail);

      if (!mounted) return;
      _showSnackBar('비밀번호 재설정 이메일이 $savedEmail 로 발송되었습니다.');

      // 이메일 인증 후 새 비밀번호 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordPage(email: savedEmail),
        ),
      );
    } catch (e) {
      _showSnackBar('비밀번호 찾기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 찾기')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: idController,
              decoration: InputDecoration(labelText: '아이디', errorText: idError),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: recoveryEmailController,
              decoration: InputDecoration(
                labelText: '비밀번호 찾기용 이메일',
                errorText: emailError,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showSendCodeDialog,
              child: const Text('코드 전송'),
            ),
          ],
        ),
      ),
    );
  }
}

// 3️⃣ 새 비밀번호 입력 화면
class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String? passwordError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> _resetPassword() async {
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

    setState(() => passwordError = null);

    if (!_isPasswordValid(newPass)) {
      setState(() => passwordError = '비밀번호 형식 오류 (8자 이상, 영문+숫자)');
      return;
    }

    if (newPass != confirmPass) {
      setState(() => passwordError = '비밀번호가 일치하지 않습니다.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('새 비밀번호 설정 이메일이 ${widget.email} 로 발송되었습니다.')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      setState(() => passwordError = '비밀번호 재설정 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 비밀번호 설정')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: newPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '새 비밀번호',
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
                labelText: '비밀번호 확인',
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
            if (passwordError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  passwordError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _resetPassword, child: const Text('완료')),
          ],
        ),
      ),
    );
  }
}
