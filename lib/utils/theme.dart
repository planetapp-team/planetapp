// theme.dart
//프론트엔드 작업 - 화면 연결과 등록
// 공통 스타일 파일
// 프론트엔드 작업 디자인 적용
// 아이콘, 색상, 폰트

import 'package:flutter/material.dart';

// --------------------- 색상 ---------------------
class AppColors {
  static const darkBrown = Color(0xFF362726); // #362726
  static const yellow = Color(0xFFFFD741); // #FFD741
  static const gray1 = Color(0xFFB0AEAE); // #B0AEAE
  static const gray2 = Color(0xFFD9D9D9); // #D9D9D9
  static const red = Color(0xFFFF4141); // #FF4141
  static const black = Color(0xFF000000); // #000000
  static const white = Color(0xFFFFFFFF); // #FFFFFFFF

  // 메인 테마 색상 (앱 대표 컬러로 지정)
  static const primary = yellow;
  static const secondary = darkBrown;
  static const background = white;
  static const textPrimary = black;
  static const textSecondary = gray1;
}

// --------------------- 폰트 ---------------------
class AppTextStyles {
  // 스플래시 화면용
  static const catchphrase = TextStyle(
    fontFamily: 'YClover', // YClover Regular
    fontSize: 25, // 25sp
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontFamily: 'YClover', // YClover Bold
    fontSize: 70, // 70sp
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // 앱 내 일반 텍스트용
  static const body = TextStyle(
    fontFamily: 'YClover',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const subtitle = TextStyle(
    fontFamily: 'YClover',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const boldBody = TextStyle(
    fontFamily: 'YClover',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}

// --------------------- 아이콘 ---------------------
class AppIcons {
  static const home = 'assets/icons/home.svg';
  static const calendar = 'assets/icons/calendar.svg';
  static const add = 'assets/icons/add.svg';
  static const edit = 'assets/icons/edit.svg';
  static const delete = 'assets/icons/delete.svg';
}
