import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Singleton pattern
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  
  // Push notification izinlerini ayarla
  static Future<void> initialize() async {
    try {
      // Web için özel ayarlar
      if (kIsWeb) {
        await _initializeWeb();
      } else {
        await _initializeMobile();
      }
      
      // Token'ı kaydet
      await _saveTokenToDatabase();
      
      // Token değişikliklerini dinle
      _messaging.onTokenRefresh.listen((token) {
        _saveTokenToDatabase();
      });
      
      // Foreground mesajları dinle
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Bildirime tıklanma durumunu dinle
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // Uygulama kapalıyken gelen bildirimleri kontrol et
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
      if (kDebugMode) {
        developer.log('Push notification service initialized successfully', name: 'PushNotificationService');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error initializing push notifications: $e', name: 'PushNotificationService');
      }
    }
  }
  
  // Web için özel initialization
  static Future<void> _initializeWeb() async {
    try {
      // Web push notifications için token al
      final token = await _messaging.getToken();
      if (kDebugMode && token != null) {
        developer.log('Web FCM Token obtained successfully', name: 'PushNotificationService');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error getting web token: $e', name: 'PushNotificationService');
      }
    }
  }
  
  // Mobile için özel initialization
  static Future<void> _initializeMobile() async {
    // iOS için özel izinler
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    if (kDebugMode) {
      developer.log('Permission granted: ${settings.authorizationStatus}', name: 'PushNotificationService');
    }
  }
  
  // FCM token'ı veritabanına kaydet
  static Future<void> _saveTokenToDatabase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final token = await _messaging.getToken();
      if (token == null) return;
      
      // Network timeout ile işlem yap
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([{
          'token': token,
          'platform': kIsWeb ? 'web' : 'mobile',
          'lastUpdated': FieldValue.serverTimestamp(),
        }])
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Network timeout: Token kaydedilemedi');
        },
      );
      
      if (kDebugMode) {
        developer.log('FCM Token saved successfully', name: 'PushNotificationService');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error saving FCM token: $e', name: 'PushNotificationService');
      }
    }
  }
  
  // Foreground mesajları işle
  static void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      developer.log('Foreground message received: ${message.messageId}', name: 'PushNotificationService');
      developer.log('Title: ${message.notification?.title}', name: 'PushNotificationService');
      developer.log('Body: ${message.notification?.body}', name: 'PushNotificationService');
    }
    
    // Bildirimi Firestore'a kaydet
    _saveNotificationToFirestore(message);
  }
  
  // Bildirime tıklanma durumunu işle
  static void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      developer.log('Notification tapped: ${message.messageId}', name: 'PushNotificationService');
    }
    
    // Navigation logic burada olacak
    final data = message.data;
    if (data.containsKey('route')) {
      // Navigate to specific screen
      // Navigator.pushNamed(context, data['route']);
    }
  }
  
  // Bildirimi Firestore'a kaydet
  static Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'title': message.notification?.title ?? 'Bildirim',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'messageId': message.messageId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving notification to Firestore: $e');
      }
    }
  }
  
  // Kullanıcıya test bildirimi gönder
  static Future<void> sendTestNotification(String userId) async {
    try {
      // Bu normalde backend'den çağrılır
      // Burada sadece Firestore'a test bildirimi ekleyeceğiz
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Test Bildirimi',
        'body': 'Bu bir test bildirimidir.',
        'data': {'type': 'test'},
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'messageId': 'test_${DateTime.now().millisecondsSinceEpoch}',
      });
      
      if (kDebugMode) {
        developer.log('Test notification sent', name: 'PushNotificationService');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error sending test notification: $e', name: 'PushNotificationService');
      }
    }
  }
  
  // Token'ı temizle (logout sırasında)
  static Future<void> clearToken() async {
    try {
      await _messaging.deleteToken();
      if (kDebugMode) {
        developer.log('FCM Token cleared', name: 'PushNotificationService');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Error clearing FCM token: $e', name: 'PushNotificationService');
      }
    }
  }
  
  // Background message handler (main.dart'ta çağrılmalı)
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    if (kDebugMode) {
      developer.log('Background message received: ${message.messageId}', name: 'PushNotificationService');
    }
    
    // Background'da bildirim işlemleri
    await _saveNotificationToFirestore(message);
  }
}
