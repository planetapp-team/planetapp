// lib/change_password_page.dart

// 설정 화면
// 회원 정보 수정 화면
// 비밀번호 재설정 화면
// 현재 비밀번호 인증 후 변경 가능

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? currentPasswordError;
  String? newPasswordError;
  String? confirmPasswordError;

  Future<void> changePassword() async {
    final user = FirebaseAuth.instance.currentUser!;
    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    currentPasswordError = null;
    newPasswordError = null;
    confirmPasswordError = null;
    bool hasError = false;

    if (currentPassword.isEmpty) {
      currentPasswordError = '현재 비밀번호를 입력해주세요.';
      hasError = true;
    }
    if (newPassword.isEmpty) {
      newPasswordError = '변경할 비밀번호를 입력해주세요.';
      hasError = true;
    } else if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$',
    ).hasMatch(newPassword)) {
      newPasswordError = '8자 이상, 영문+숫자 포함이어야 합니다.';
      hasError = true;
    }
    if (confirmPassword.isEmpty) {
      confirmPasswordError = '비밀번호를 한 번 더 입력해주세요.';
      hasError = true;
    } else if (newPassword != confirmPassword) {
      confirmPasswordError = '비밀번호가 일치하지 않습니다.';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(newPassword);
      await user.reload();

      if (!mounted) return;
      await _showSuccessDialog('비밀번호가 정상적으로 변경되었습니다.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          (e.message != null &&
              e.message!.toLowerCase().contains('password'))) {
        currentPasswordError = '현재 비밀번호가 일치하지 않습니다.';
        setState(() {});
      } else {
        await _showErrorDialog('비밀번호 변경 중 오류가 발생했습니다: ${e.message}');
      }
    } catch (e) {
      await _showErrorDialog('예상치 못한 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // 팝업창 배경 흰색
        title: const Text(
          '성공',
          style: TextStyle(color: Colors.black), // 텍스트 검정
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.black), // 텍스트 검정
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(color: Colors.black), // 버튼 텍스트 검정
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 재설정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: '현재 비밀번호',
                  hintText: '현재 비밀번호를 입력해주세요.',
                  errorText: currentPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: '새 비밀번호',
                  hintText: '8자 이상, 영문+숫자 포함',
                  errorText: newPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  hintText: '비밀번호를 한 번 더 입력해주세요.',
                  errorText: confirmPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: changePassword,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: AppColors.gray2, // 버튼 색상 theme.dart 적용
                      ),
                      child: const Text(
                        '변경하기',
                        style: TextStyle(
                          color: AppColors.black, // 텍스트 검정
                          fontWeight: FontWeight.bold, // 텍스트 bold
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
