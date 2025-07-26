// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyACl-WJ00KPoYs718DO_Qzl6xOgYyaPUrM",
  authDomain: "mapchat-23288.firebaseapp.com",
  projectId: "mapchat-23288",
  storageBucket: "mapchat-23288.firebasestorage.app",
  messagingSenderId: "35933174888",
  appId: "1:35933174888:web:b5160f53ebe9f4db970fdd"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Initialize Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'MapChat';
  const notificationOptions = {
    body: payload.notification?.body || 'Yeni bir mesajınız var',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'mapchat-notification',
    requireInteraction: true,
    vibrate: [200, 100, 200],
    data: {
      url: payload.data?.url || '/',
      notificationId: payload.data?.notificationId,
      userId: payload.data?.userId,
      type: payload.data?.type,
      ...payload.data
    },
    actions: [
      {
        action: 'open',
        title: 'Aç',
        icon: '/icons/Icon-192.png'
      },
      {
        action: 'close',
        title: 'Kapat'
      }
    ]
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notification click received.', event);
  
  event.notification.close();
  
  const action = event.action;
  const data = event.notification.data || {};
  
  if (action === 'close') {
    return; // Sadece kapat
  }
  
  // Uygulamayı aç veya odaklan
  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    }).then(function(clientList) {
      console.log('Found clients:', clientList.length);
      
      // Açık bir MapChat penceresi var mı kontrol et
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          // Varolan pencereyi odakla ve bildirim verisini gönder
          client.postMessage({
            type: 'NOTIFICATION_CLICKED',
            data: data
          });
          return client.focus();
        }
      }
      
      // Yeni pencere aç
      if (clients.openWindow) {
        const targetUrl = data.url || '/';
        return clients.openWindow(targetUrl);
      }
    }).catch(error => {
      console.error('Error handling notification click:', error);
    })
  );
});

// Push mesajı alındığında (iOS Safari için)
self.addEventListener('push', function(event) {
  console.log('[firebase-messaging-sw.js] Push received: ', event);
  
  if (!event.data) {
    console.log('Push event has no data');
    return;
  }
  
  try {
    const payload = event.data.json();
    console.log('Push payload: ', payload);
    
    const notificationTitle = payload.notification?.title || 'MapChat';
    const notificationOptions = {
      body: payload.notification?.body || 'Yeni bir mesajınız var',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag: 'mapchat-push',
      requireInteraction: true,
      vibrate: [200, 100, 200],
      data: payload.data || {},
      actions: [
        {
          action: 'open',
          title: 'Aç'
        },
        {
          action: 'close',
          title: 'Kapat'
        }
      ]
    };
    
    event.waitUntil(
      self.registration.showNotification(notificationTitle, notificationOptions)
    );
  } catch (error) {
    console.error('Error parsing push payload:', error);
  }
});

// Service Worker kurulumu
self.addEventListener('install', function(event) {
  console.log('[firebase-messaging-sw.js] Service Worker installed');
  self.skipWaiting();
});

// Service Worker aktivasyonu
self.addEventListener('activate', function(event) {
  console.log('[firebase-messaging-sw.js] Service Worker activated');
  event.waitUntil(self.clients.claim());
});

// Ana thread'den mesaj alma
self.addEventListener('message', function(event) {
  console.log('[firebase-messaging-sw.js] Received message:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
