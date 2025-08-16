// lib/member_edit_page.dart
// 회원정보 수정 페이지
// - 닉네임 수정 가능
// - 비밀번호 변경
// - 비밀번호 확인
// - 생년월일 선택
// - 수정 완료 후 프로필 화면으로 이동
// - 비밀번호 재설정 버튼 추가 (새 화면 연결)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MemberEditPage extends StatefulWidget {
  const MemberEditPage({super.key});

  @override
  State<MemberEditPage> createState() => _MemberEditPageState();
}

class _MemberEditPageState extends State<MemberEditPage> {
  final user = FirebaseAuth.instance.currentUser!;
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController birthController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String? nicknameError;
  String? passwordError;
  String? confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        nicknameController.text = doc.data()?['nickname'] ?? '';
        birthController.text = doc.data()?['birth'] ?? '';
      } else {
        nicknameController.text = user.displayName ?? '';
      }
    } catch (e) {
      nicknameController.text = user.displayName ?? '';
    }
  }

  void _clearErrors() {
    nicknameError = null;
    passwordError = null;
    confirmPasswordError = null;
  }

  Future<void> updateMemberInfo() async {
    _clearErrors();
    bool hasError = false;

    final nickname = nicknameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final birth = birthController.text.trim();

    if (nickname.isEmpty) {
      nicknameError = '닉네임을 입력하세요';
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
    if (birth.isNotEmpty && !RegExp(r'^\d{8}$').hasMatch(birth)) {
      _showSnackBar('생년월일은 8자리 숫자(YYYYMMDD)로 입력해주세요');
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      await user.updateDisplayName(nickname);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nickname': nickname,
        'birth': birth.isEmpty ? null : birth,
      }, SetOptions(merge: true));

      if (password.isNotEmpty) {
        await user.updatePassword(password);
      }

      await user.reload();

      if (!mounted) return;
      _showSnackBar('회원정보가 수정되었습니다.');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showSnackBar('수정 실패: ${e.message}');
    } catch (e) {
      _showSnackBar('예상치 못한 오류: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    nicknameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    birthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원정보 수정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nicknameController,
                decoration: InputDecoration(
                  label: _buildLabelWithStar('닉네임'),
                  errorText: nicknameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  label: _buildLabelWithStar('비밀번호'),
                  hintText: '8자 이상 영문+숫자 포함',
                  errorText: passwordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  label: _buildLabelWithStar('비밀번호 확인'),
                  hintText: '비밀번호를 한번 더 입력해주세요.',
                  errorText: confirmPasswordError,
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
              const SizedBox(height: 12),
              TextField(
                controller: birthController,
                decoration: const InputDecoration(
                  labelText: '생년월일 (선택)',
                  hintText: 'YYYYMMDD (8자리 숫자)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: updateMemberInfo,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          '수정 완료',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/resetPassword');
                  },
                  child: const Text(
                    '비밀번호 재설정',
                    style: TextStyle(
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabelWithStar(String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black, fontSize: 16),
          ),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
