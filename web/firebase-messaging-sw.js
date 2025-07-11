// firebase-messaging-sw.js 
// Flutter 웹에서 FCM 사용할 때 필수 파일입니다.
// 이 파일 없거나 잘못되면 서비스워커 등록 실패 에러가 발생합니다.
// Chrome 개발자 도구 → Application → Service Workers 탭에서 서비스워커 등록 상태 확인 가능

importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyB3tw0rTh51eZyqpJB__czaj8jduswx5SM",
  authDomain: "planet-app-2b6b4.firebaseapp.com",
  projectId: "planet-app-2b6b4",
  storageBucket: "planet-app-2b6b4.firebasestorage.app",
  messagingSenderId: "445871757885",
  appId: "1:445871757885:web:e9074c3e20aacfea6ce854",
  measurementId: "G-D6VS30MK0N"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    // icon: '/firebase-logo.png' // 필요하면 알림 아이콘 경로 설정
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
