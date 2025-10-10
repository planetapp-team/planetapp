// lib/profile_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'member_edit_page.dart'; // 회원정보 수정 페이지

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser!;
  String? nickname = '';
  String? email = '';
  String? createdAt = '';

  bool _isLoading = true;

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
        final data = doc.data();
        nickname = data?['nickname'] ?? '';
        email = data?['emailId'] ?? '';
        final ts = data?['createdAt'] as Timestamp?;
        if (ts != null) {
          final date = ts.toDate();
          createdAt =
              '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
        }
      }
    } catch (e) {
      print('프로필 정보 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  // 로그아웃 처리
  void signOut() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
    }
  }

  // 탈퇴하기 처리
  void deleteAccount() async {
    final passwordController = TextEditingController();
    bool _obscureText = true; // 비밀번호 가리기 상태

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white, // ✅ 배경 흰색
              title: const Text(
                '비밀번호 확인',
                style: TextStyle(color: Colors.black), // ✅ 제목 검정색
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '계정 삭제 시 현재비밀번호를 입력하세요.',
                    style: TextStyle(color: Colors.black), // ✅ 안내문 검정색
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      labelStyle: const TextStyle(color: Colors.black),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black54),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    '확인',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordController.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
      await user.delete();
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('계정이 삭제되었습니다.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname ?? '',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 16),

                  const Text(
                    '내 계정 관리',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MemberEditPage(),
                        ),
                      ).then((_) => _loadUserInfo());
                    },
                    child: const Text(
                      '회원 정보 수정',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildInfoRow('아이디', email ?? '', isEditable: false),
                  _buildInfoRow('계정 생성일', createdAt ?? '', isEditable: false),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text(
                    '시스템 관리',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('이용약관 페이지로 이동')),
                      );
                    },
                    child: const Text(
                      '이용약관',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: signOut,
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: deleteAccount,
                    child: const Text(
                      '탈퇴하기',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isEditable = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isEditable ? Colors.black : Colors.grey,
                fontWeight: isEditable ? FontWeight.normal : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
