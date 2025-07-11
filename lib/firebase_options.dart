// firebase_options.dart
// FlutterFire CLI로 자동 생성되는 Firebase 설정 옵션 모음 파일
// 플랫폼별 Firebase 설정 값 포함 (웹, Android 등)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3tw0rTh51eZyqpJB__czaj8jduswx5SM',
    appId: '1:445871757885:web:e9074c3e20aacfea6ce854',
    messagingSenderId: '445871757885',
    projectId: 'planet-app-2b6b4',
    authDomain: 'planet-app-2b6b4.firebaseapp.com',
    storageBucket: 'planet-app-2b6b4.firebasestorage.app',
    measurementId: 'G-D6VS30MK0N',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCzA4wP4gi58xYUgSJm_iXHP0djTYf72SA',
    appId: '1:445871757885:android:7f50704ecf185ddb6ce854',
    messagingSenderId: '445871757885',
    projectId: 'planet-app-2b6b4',
    storageBucket: 'planet-app-2b6b4.firebasestorage.app',
  );
}
