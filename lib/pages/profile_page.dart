// lib/profile_page.dart
//프로필 관리
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser!;
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNicknameFromFirestore();
    emailController.text = user.email ?? '';
  }

  Future<void> _loadNicknameFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final nickname = doc.data()?['nickname'] as String?;
        if (nickname != null) {
          displayNameController.text = nickname;
        } else {
          displayNameController.text = user.displayName ?? '';
        }
      } else {
        displayNameController.text = user.displayName ?? '';
      }
    } catch (e) {
      // 에러 무시하거나 로그 출력
      displayNameController.text = user.displayName ?? '';
    }
  }

  Future<void> updateProfile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newNickname = displayNameController.text.trim();
      final newEmail = emailController.text.trim();

      // FirebaseAuth 프로필 닉네임 업데이트 (선택사항)
      await user.updateDisplayName(newNickname);

      // Firestore 닉네임 업데이트 - 홈화면 실시간 반영을 위해 필수!
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nickname': newNickname,
      }, SetOptions(merge: true));

      // 이메일 변경 필요 시만
      if (newEmail != user.email) {
        await user.updateEmail(newEmail);
      }

      await user.reload();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로필이 성공적으로 업데이트되었습니다.')));
        setState(() {});
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
          _isLoading = false;
        });
      }
    }
  }

  void signOut() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
    }
  }

  void deleteAccount() async {
    final passwordController = TextEditingController();
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
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final email = user.email!;
      final password = passwordController.text.trim();

      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      await user.delete();
      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        Navigator.of(context).pop();
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
              TextField(
                controller: displayNameController,
                decoration: const InputDecoration(labelText: '닉네임'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: '이메일'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: updateProfile,
                      child: const Text('프로필 수정'),
                    ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/changePassword');
                },
                child: const Text('비밀번호 변경'),
              ),
              const SizedBox(height: 40),
              const Divider(),
              ElevatedButton(onPressed: signOut, child: const Text('로그아웃')),
              const SizedBox(height: 10),
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
