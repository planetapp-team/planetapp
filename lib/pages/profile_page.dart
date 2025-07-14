// lib/profile_page.dart
// 프로필 관리 페이지
// - 닉네임 변경
// - 이메일 변경
// - 비밀번호 변경 화면으로 이동
// - 로그아웃 기능
// - 계정 삭제 (현재 비밀번호 확인 후 삭제)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser!; // 현재 로그인한 사용자
  final TextEditingController displayNameController =
      TextEditingController(); // 닉네임 입력 컨트롤러
  final TextEditingController emailController =
      TextEditingController(); // 이메일 입력 컨트롤러

  bool _isLoading = false; // 프로필 수정 처리중 상태

  @override
  void initState() {
    super.initState();
    _loadNicknameFromFirestore(); // Firestore에서 닉네임 불러오기
    emailController.text = user.email ?? ''; // 현재 이메일 텍스트 필드에 세팅
  }

  // Firestore에서 users 컬렉션의 현재 사용자 닉네임 로드
  Future<void> _loadNicknameFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final nickname = doc.data()?['nickname'] as String?;
        if (nickname != null) {
          displayNameController.text = nickname; // Firestore 닉네임이 있으면 세팅
        } else {
          displayNameController.text =
              user.displayName ?? ''; // 없으면 FirebaseAuth 닉네임 세팅
        }
      } else {
        displayNameController.text =
            user.displayName ?? ''; // 문서가 없으면 FirebaseAuth 닉네임 세팅
      }
    } catch (e) {
      // 에러 발생 시 FirebaseAuth 닉네임 세팅, 로그 출력하거나 무시 가능
      displayNameController.text = user.displayName ?? '';
    }
  }

  // 프로필 수정 처리 함수
  Future<void> updateProfile() async {
    if (_isLoading) return; // 이미 처리 중이면 중복 방지

    setState(() {
      _isLoading = true; // 로딩 시작
    });

    try {
      final newNickname = displayNameController.text.trim();
      final newEmail = emailController.text.trim();

      // FirebaseAuth 사용자 닉네임 업데이트 (선택사항)
      await user.updateDisplayName(newNickname);

      // Firestore 닉네임 업데이트 (실시간 반영을 위해 필수)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nickname': newNickname,
      }, SetOptions(merge: true));

      // 이메일이 변경된 경우에만 이메일 업데이트 수행
      if (newEmail != user.email) {
        await user.updateEmail(newEmail);
      }

      await user.reload(); // 사용자 정보 새로고침

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')));
        setState(() {}); // 화면 갱신
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('프로필 업데이트 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // 로딩 종료
        });
      }
    }
  }

  // 로그아웃 처리 함수
  void signOut() async {
    await FirebaseAuth.instance.signOut(); // Firebase 로그아웃
    if (context.mounted) {
      Navigator.of(context).pop(); // 이전 화면으로 이동
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
    }
  }

  // 계정 삭제 처리 함수 (비밀번호 확인 다이얼로그 띄움)
  void deleteAccount() async {
    final passwordController = TextEditingController();

    // 비밀번호 입력 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('계정을 삭제하려면 비밀번호를 입력하세요.'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true, // 비밀번호 가리기
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // 취소 버튼
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // 확인 버튼
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirm != true) return; // 취소하면 종료

    try {
      final email = user.email!;
      final password = passwordController.text.trim();

      // 현재 비밀번호로 재인증
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // 사용자 계정 삭제
      await user.delete();

      // 삭제 후 로그아웃
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pop(); // 이전 화면으로 이동
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('계정이 삭제되었습니다.')));
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: ${e.message}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('예상치 못한 오류: $e')));
      }
    }
  }

  @override
  void dispose() {
    // 컨트롤러 메모리 해제
    displayNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 관리')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 닉네임 입력 필드
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(labelText: '닉네임'),
              ),
              const SizedBox(height: 12),
              // 이메일 입력 필드
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              // 프로필 수정 버튼 또는 로딩 표시
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: updateProfile,
                      child: const Text('프로필 수정'),
                    ),
              const SizedBox(height: 20),
              // 비밀번호 변경 화면으로 이동 버튼
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/changePassword');
                },
                child: const Text('비밀번호 변경'),
              ),
              const SizedBox(height: 40),
              const Divider(),
              // 로그아웃 버튼
              ElevatedButton(onPressed: signOut, child: const Text('로그아웃')),
              const SizedBox(height: 10),
              // 계정 삭제 버튼 (빨간색)
              ElevatedButton(
                onPressed: deleteAccount,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('계정 삭제'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
