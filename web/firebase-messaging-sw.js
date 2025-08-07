// Firebase Cloud Messaging Service Worker

importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Firebase configuration
const firebaseConfig = {
  apiKey: "${FIREBASE_API_KEY}",
  authDomain: "startend-app-6b2e4.firebaseapp.com",
  projectId: "startend-app-6b2e4",
  storageBucket: "startend-app-6b2e4.appspot.com",
  messagingSenderId: "201575475230",
  appId: "1:201575475230:web:7b2e4c6d8f9a0b1c2d3e4f"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Initialize Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  // バックグラウンドメッセージのログは本番環境では無効化
  if (typeof console !== 'undefined' && console.log) {
    console.log('Background message received: ', payload);
  }
  
  const notificationTitle = payload.notification?.title || 'StartEnd';
  const notificationOptions = {
    body: payload.notification?.body || 'New notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'startend-notification',
    requireInteraction: true,
    actions: [
      {
        action: 'open',
        title: '開く'
      },
      {
        action: 'close',
        title: '閉じる'
      }
    ]
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  if (event.action === 'open') {
    // Open the app
    event.waitUntil(
      clients.openWindow('/')
    );
  }
}); 