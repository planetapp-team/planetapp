// lib/member_edit_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/theme.dart';

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

    if (nickname.isEmpty) {
      nicknameError = '닉네임을 입력하세요';
      hasError = true;
    }
    if (password.isEmpty) {
      passwordError = '현재 비밀번호를 입력하세요';
      hasError = true;
    }

    if (password.isNotEmpty && confirmPassword.isNotEmpty) {
      if (!RegExp(
        r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$',
      ).hasMatch(confirmPassword)) {
        confirmPasswordError = '8자 이상 영문+숫자 포함.';
        hasError = true;
      }
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔹 현재 비밀번호 재확인 (재인증)
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // 🔹 닉네임 중복 확인
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .get();

      if (existing.docs.isNotEmpty && existing.docs.first.id != user.uid) {
        nicknameError = '이미 사용 중인 닉네임입니다.';
        setState(() => _isLoading = false);
        return;
      }

      // 🔹 닉네임 업데이트
      await user.updateDisplayName(nickname);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nickname': nickname,
      }, SetOptions(merge: true));

      // 🔹 새 비밀번호로 변경 (선택 시)
      if (confirmPassword.isNotEmpty) {
        await user.updatePassword(confirmPassword);
      }

      await user.reload();

      if (!mounted) return;
      _showSuccessDialog('닉네임이 성공적으로 변경되었습니다.');
    } on FirebaseAuthException catch (e) {
      // 🔸 사용자에게는 깔끔한 문구만 표시
      if (e.code == 'wrong-password') {
        _showErrorDialog('현재 비밀번호가 틀렸습니다.');
      } else {
        _showErrorDialog('현재 비밀번호를 다시 확인해주세요.');
      }
    } catch (_) {
      // 🔸 기타 예외도 사용자에게 단순한 문구로 안내
      _showErrorDialog('닉네임 변경 중 오류가 발생했습니다.\n다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('완료'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.black),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('실패'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.black),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nicknameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('닉네임 수정'),
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
                  label: _buildLabelWithStar('현재 비밀번호'),
                  hintText: '현재 비밀번호를 입력해주세요.',
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
                  label: const Text('비밀번호 확인'),
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

              const SizedBox(height: 20),

              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: updateMemberInfo,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(200, 50),
                          backgroundColor: AppColors.gray2,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          '수정 완료',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/resetPassword');
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.black),
                  child: const Text(
                    '비밀번호 재설정',
                    style: TextStyle(decoration: TextDecoration.underline),
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
