// firebase_options.dart
// FlutterFire CLI로 자동 생성되는 Firebase 설정 옵션 모음 파일
// 각 플랫폼별 Firebase 초기화에 필요한 설정 값들을 포함함 (웹, Android 등)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  // 현재 실행 중인 플랫폼에 맞는 FirebaseOptions 반환
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // 웹 플랫폼일 경우 web 설정 반환
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android 플랫폼일 경우 android 설정 반환
        return android;
      case TargetPlatform.iOS:
        // iOS 설정 미구성 시 예외 발생
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        // macOS 설정 미구성 시 예외 발생
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        // Windows 설정 미구성 시 예외 발생
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        // Linux 설정 미구성 시 예외 발생
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        // 지원하지 않는 플랫폼일 경우 예외 발생
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // 웹 플랫폼 Firebase 설정 값
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3tw0rTh51eZyqpJB__czaj8jduswx5SM',
    appId: '1:445871757885:web:e9074c3e20aacfea6ce854',
    messagingSenderId: '445871757885',
    projectId: 'planet-app-2b6b4',
    authDomain: 'planet-app-2b6b4.firebaseapp.com',
    storageBucket: 'planet-app-2b6b4.firebasestorage.app',
    measurementId: 'G-D6VS30MK0N',
  );

  // Android 플랫폼 Firebase 설정 값
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCzA4wP4gi58xYUgSJm_iXHP0djTYf72SA',
    appId: '1:445871757885:android:7f50704ecf185ddb6ce854',
    messagingSenderId: '445871757885',
    projectId: 'planet-app-2b6b4',
    storageBucket: 'planet-app-2b6b4.firebasestorage.app',
  );
}
