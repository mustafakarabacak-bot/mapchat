import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static FirebaseOptions get webOptions => const FirebaseOptions(
    apiKey: 'AIzaSyACl-WJ00KPoYs718DO_Qzl6xOgYyaPUrM',
    authDomain: 'mapchat-23288.firebaseapp.com',
    projectId: 'mapchat-23288',
    storageBucket: 'mapchat-23288.firebasestorage.app',
    messagingSenderId: '35933174888',
    appId: '1:35933174888:web:b5160f53ebe9f4db970fdd',
    measurementId: 'G-NDKT44N0J2',
  );
  
  static FirebaseOptions get androidOptions => const FirebaseOptions(
    apiKey: 'AIzaSyD7KNSCYc9bROh-qK0XD3S2P8QnVtF4-Ic',
    authDomain: 'mapchat-23288.firebaseapp.com',
    projectId: 'mapchat-23288',
    storageBucket: 'mapchat-23288.firebasestorage.app',
    messagingSenderId: '35933174888',
    appId: '1:35933174888:android:1234567890abcdef',
  );
  
  static FirebaseOptions get iosOptions => const FirebaseOptions(
    apiKey: 'AIzaSyD7KNSCYc9bROh-qK0XD3S2P8QnVtF4-Ic',
    authDomain: 'mapchat-23288.firebaseapp.com',
    projectId: 'mapchat-23288',
    storageBucket: 'mapchat-23288.firebasestorage.app',
    messagingSenderId: '35933174888',
    appId: '1:35933174888:ios:1234567890abcdef',
  );
}
