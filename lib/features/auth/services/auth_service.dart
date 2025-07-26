import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:typed_data';
import 'dart:io';
import 'dart:developer' as developer;

// Custom exception class for better error handling
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage =
      firebase_storage.FirebaseStorage.instance;

  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  // Stream getter for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  AuthService() {
    // Initialize current user
    _user = _auth.currentUser;

    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // Check username availability
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      return !usernameDoc.exists;
    } catch (e) {
      throw 'Kullanıcı adı kontrolü sırasında hata oluştu: $e';
    }
  }

  // Check phone number availability
  Future<bool> checkPhoneAvailability(String phoneNumber) async {
    try {
      final phoneQuery = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();
      return phoneQuery.docs.isEmpty;
    } catch (e) {
      throw 'Telefon numarası kontrolü sırasında hata oluştu: $e';
    }
  }

  // Check email availability
  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email);
    } catch (e) {
      developer.log('Error checking email availability: $e');
      return [];
    }
  }

  // Complete user profile after verification
  Future<void> completeUserProfile({
    required String email,
    required String name,
    required String username,
    String? profileImageUrl,
    required String gender,
    required DateTime birthDate,
    required String phoneNumber,
    required bool locationPermission,
    required bool notificationPermission,
    required String profileVisibility,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Kullanıcı oturumu bulunamadı';

      // Update user document in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'username': username.toLowerCase(),
        'profileImageUrl': profileImageUrl,
        'gender': gender,
        'birthDate': Timestamp.fromDate(birthDate),
        'phoneNumber': phoneNumber,
        'locationPermission': locationPermission,
        'notificationPermission': notificationPermission,
        'profileVisibility': profileVisibility,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Profil tamamlanırken hata oluştu: $e';
    }
  }

  // Reserve username
  Future<void> reserveUsername(String username) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Kullanıcı oturumu bulunamadı';

      // Reserve username in usernames collection
      await _firestore.collection('usernames').doc(username.toLowerCase()).set({
        'userId': user.uid,
        'username': username.toLowerCase(),
        'reservedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Kullanıcı adı rezerve edilirken hata oluştu: $e';
    }
  }

  // Upload profile image with error handling
  Future<String?> uploadProfileImage(File? imageFile) async {
    if (imageFile == null) return null;

    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Kullanıcı oturumu bulunamadı';

      // Check file size (max 5MB)
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw 'Resim boyutu 5MB\'dan büyük olamaz';
      }

      // Check file extension
      final fileName = imageFile.path.toLowerCase();
      if (!fileName.endsWith('.jpg') &&
          !fileName.endsWith('.jpeg') &&
          !fileName.endsWith('.png')) {
        throw 'Sadece JPG, JPEG ve PNG formatları desteklenir';
      }

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final uniqueFileName = '${user.uid}_$timestamp.$extension';

      // Upload to Firebase Storage
      final ref = _storage.ref().child('profile_images/$uniqueFileName');
      final uploadTask = ref.putFile(imageFile);

      // Wait for upload completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      if (e.toString().contains('network')) {
        throw 'İnternet bağlantısı hatası. Lütfen tekrar deneyin.';
      } else if (e.toString().contains('storage')) {
        throw 'Resim yükleme hatası. Lütfen tekrar deneyin.';
      } else {
        throw 'Resim yükleme hatası: $e';
      }
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Register with email and password
  Future<String?> registerWithEmail(
      String email, String password, String username, String fullName) async {
    try {
      _setLoading(true);

      // Check if username already exists
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      if (usernameDoc.exists) {
        return 'Bu kullanıcı adı zaten kullanılıyor';
      }

      // Create user
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user document
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'username': username.toLowerCase(),
          'fullName': fullName,
          'createdAt': FieldValue.serverTimestamp(),
          'profileImageUrl': null,
          'bio': '',
        });

        // Reserve username
        await _firestore
            .collection('usernames')
            .doc(username.toLowerCase())
            .set({
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update display name
        await userCredential.user!.updateDisplayName(fullName);
        await userCredential.user!.reload();
        _user = _auth.currentUser;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'Şifre çok zayıf';
        case 'email-already-in-use':
          return 'Bu e-posta adresi zaten kullanılıyor';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi';
        default:
          return 'Kayıt olurken hata oluştu: ${e.message}';
      }
    } catch (e) {
      return 'Beklenmeyen bir hata oluştu';
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with email/username and password
  Future<String?> signInWithEmailOrUsername(
      String loginInput, String password) async {
    try {
      _setLoading(true);

      String email = loginInput;

      // Check if input is username (no @ symbol)
      if (!loginInput.contains('@')) {
        // Look up email by username
        final usernameDoc = await _firestore
            .collection('usernames')
            .doc(loginInput.toLowerCase())
            .get();
        if (!usernameDoc.exists) {
          return 'Kullanıcı bulunamadı';
        }

        final userDoc = await _firestore
            .collection('users')
            .doc(usernameDoc.data()!['uid'])
            .get();
        if (!userDoc.exists) {
          return 'Kullanıcı bulunamadı';
        }

        email = userDoc.data()!['email'];
      }

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Kullanıcı bulunamadı';
        case 'wrong-password':
          return 'Hatalı şifre';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi';
        case 'user-disabled':
          return 'Bu hesap devre dışı bırakılmış';
        default:
          return 'Giriş yaparken hata oluştu: ${e.message}';
      }
    } catch (e) {
      return 'Beklenmeyen bir hata oluştu';
    } finally {
      _setLoading(false);
    }
  }

  // Email ile giriş (eski method - geriye dönük uyumluluk için)
  Future<String?> signInWithEmail(String email, String password) async {
    return signInWithEmailOrUsername(email, password);
  }

  // Email ile kayıt (eski method - geriye dönük uyumluluk için)
  Future<String?> signUpWithEmail(
      String email, String password, String name) async {
    // Generate username from email
    String username = email.split('@')[0].toLowerCase();
    return registerWithEmail(email, password, username, name);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      developer.log('Sign out error: $e');
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final doc = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      return !doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw 'E-posta doğrulama gönderilirken hata oluştu: $e';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      if (e.toString().contains('user-not-found')) {
        throw 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
      } else if (e.toString().contains('invalid-email')) {
        throw 'Geçersiz e-posta adresi';
      } else {
        throw 'Şifre sıfırlama e-postası gönderilirken hata oluştu';
      }
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      _setLoading(true);

      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } catch (e) {
      if (e.toString().contains('user-not-found')) {
        throw 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
      } else if (e.toString().contains('wrong-password')) {
        throw 'Hatalı şifre';
      } else if (e.toString().contains('invalid-email')) {
        throw 'Geçersiz e-posta adresi';
      } else if (e.toString().contains('too-many-requests')) {
        throw AuthException('Çok fazla deneme. Lütfen daha sonra tekrar deneyin');
      } else {
        throw AuthException('Giriş yapılırken hata oluştu: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // Create user with email and password, save to Firestore
  Future<User?> createUserWithEmailAndPassword(
      String email, String name, String password) async {
    try {
      _setLoading(true);

      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Save user data to Firestore (verification code artık kaydetmiyoruz)
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': true, // Artık doğrulama yapmıyoruz
          'isActive': true, // Direkt aktif
          'profileCompleted': false,
        });
      }

      return userCredential.user;
    } catch (e) {
      if (e.toString().contains('email-already-in-use')) {
        throw 'Bu e-posta adresi zaten kullanımda';
      } else if (e.toString().contains('invalid-email')) {
        throw 'Geçersiz e-posta adresi';
      } else {
        throw 'Kayıt olurken hata oluştu: $e';
      }
    } finally {
      _setLoading(false);
    }
  }

  // Verify email with code
  Future<bool> verifyEmailWithCode(String email, String inputCode) async {
    try {
      _setLoading(true);

      // Get verification code from Firestore
      final doc =
          await _firestore.collection('verification_codes').doc(email).get();

      if (!doc.exists) {
        throw 'Doğrulama kodu bulunamadı';
      }

      final data = doc.data()!;
      final storedCode = data['code'] as String;
      final expiresAt = data['expiresAt'] as Timestamp;

      // Check if code expired
      if (DateTime.now().isAfter(expiresAt.toDate())) {
        throw 'Doğrulama kodu süresi doldu';
      }

      // Check if code matches
      if (storedCode != inputCode) {
        throw 'Hatalı doğrulama kodu';
      }

      // Update user verification status
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        await userDoc.reference.update({
          'emailVerified': true,
          'isActive': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        // Send actual email verification
        final user = _auth.currentUser;
        if (user != null) {
          await user.sendEmailVerification();
        }
      }

      // Clean up verification code
      await _firestore.collection('verification_codes').doc(email).delete();

      return true;
    } catch (e) {
      throw e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Profil resmini Firebase Storage'a yükle (yeni metod)
  Future<String> uploadProfileImageBytes(
      List<int> imageBytes, String username) async {
    try {
      final String fileName =
          'profile_images/${_user?.uid}_${username}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final firebase_storage.Reference ref = _storage.ref().child(fileName);

      final firebase_storage.UploadTask uploadTask =
          ref.putData(imageBytes as Uint8List);

      final firebase_storage.TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      developer.log('Profile image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      developer.log('Error uploading profile image: $e');
      throw 'Profil resmi yüklenirken hata oluştu: $e';
    }
  }

  // Kullanıcı profilini güncelle
  Future<void> updateUserProfile({
    required String username,
    String? profileImageUrl,
  }) async {
    try {
      if (_user == null) throw 'Kullanıcı bulunamadı';

      final Map<String, dynamic> userData = {
        'username': username.toLowerCase(),
        'displayName': username,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (profileImageUrl != null) {
        userData['profileImageUrl'] = profileImageUrl;
      }

      await _firestore.collection('users').doc(_user!.uid).update(userData);

      developer.log('User profile updated successfully');
    } catch (e) {
      developer.log('Error updating user profile: $e');
      throw 'Profil güncellenirken hata oluştu: $e';
    }
  }

  // Update user profile with detailed information
  Future<void> updateCompleteUserProfile({
    required String email,
    required String name,
    required String username,
    String? profileImageUrl,
    required String gender,
    required DateTime birthDate,
    required String phoneNumber,
  }) async {
    try {
      if (_user == null) {
        throw 'Kullanıcı oturum açmamış';
      }

      // Kullanıcı verilerini hazırla
      Map<String, dynamic> userData = {
        'email': email,
        'name': name,
        'username': username,
        'gender': gender,
        'birthDate': Timestamp.fromDate(birthDate),
        'phoneNumber': phoneNumber,
        'updatedAt': Timestamp.now(),
        'profileCompleted': true,
      };

      // Profil resmi varsa ekle
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        userData['profileImageUrl'] = profileImageUrl;
      }

      // Firestore'a kaydet
      await _firestore.collection('users').doc(_user!.uid).update(userData);

      developer.log('Detailed user profile updated successfully');
    } catch (e) {
      developer.log('Error updating detailed user profile: $e');
      throw 'Profil güncellenirken hata oluştu: $e';
    }
  }

  // Update only user details (gender, birthDate, phone) - for ProfileDetailsScreen
  Future<void> updateUserDetails({
    required String gender,
    required DateTime birthDate,
    required String phoneNumber,
  }) async {
    try {
      if (_user == null) {
        throw 'Kullanıcı oturum açmamış';
      }

      // Sadece kişisel detayları güncelle
      Map<String, dynamic> detailsData = {
        'gender': gender,
        'birthDate': Timestamp.fromDate(birthDate),
        'phoneNumber': phoneNumber,
        'updatedAt': Timestamp.now(),
      };

      // Firestore'a kaydet
      await _firestore.collection('users').doc(_user!.uid).update(detailsData);

      developer.log('User details updated successfully');
    } catch (e) {
      developer.log('Error updating user details: $e');
      throw 'Kişisel bilgiler güncellenirken hata oluştu: $e';
    }
  }

  // Mark profile as completed - for ProfileDetailsScreen final step
  Future<void> markProfileAsCompleted() async {
    try {
      if (_user == null) {
        throw 'Kullanıcı oturum açmamış';
      }

      // Profili tamamlandı olarak işaretle
      await _firestore.collection('users').doc(_user!.uid).update({
        'profileCompleted': true,
        'completedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      developer.log('Profile marked as completed successfully');
    } catch (e) {
      developer.log('Error marking profile as completed: $e');
      throw 'Profil tamamlanırken hata oluştu: $e';
    }
  }

  // Create user with complete profile (one step registration)
  Future<User?> createUserWithCompleteProfile({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required DateTime birthDate,
    required String gender,
    Uint8List? profileImageBytes,
    String? profileImageName,
  }) async {
    try {
      _setLoading(true);

      // Check if username is available
      final isUsernameAvailable = await checkUsernameAvailability(username);
      if (!isUsernameAvailable) {
        throw 'Bu kullanıcı adı zaten kullanılıyor';
      }

      // Create Firebase user
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final user = userCredential.user!;
        final fullName = '$firstName $lastName';

        // Update display name
        await user.updateDisplayName(fullName);

        String? profileImageUrl;
        
        // Upload profile image if provided
        if (profileImageBytes != null && profileImageName != null) {
          try {
            final imageRef = _storage
                .ref()
                .child('profile_images')
                .child('${user.uid}_profile.jpg');
            
            await imageRef.putData(profileImageBytes);
            profileImageUrl = await imageRef.getDownloadURL();
            developer.log('Profile image uploaded successfully');
          } catch (e) {
            developer.log('Error uploading profile image: $e');
            // Continue without profile image
          }
        }

        // Create complete user document
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'name': fullName,
          'username': username.toLowerCase(),
          'phone': phone,
          'phoneNumber': phone, // Add both for compatibility
          'birthDate': Timestamp.fromDate(birthDate),
          'gender': gender,
          'bio': '',
          'profileImageUrl': profileImageUrl,
          'galleryImages': [],
          'profileCompleted': true,
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Reserve username
        await _firestore
            .collection('usernames')
            .doc(username.toLowerCase())
            .set({
          'userId': user.uid,
          'username': username.toLowerCase(),
          'reservedAt': FieldValue.serverTimestamp(),
        });

        // Save contact info to separate collection
        await _firestore
            .collection('user_contacts')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'fullName': fullName,
          'phone': phone,
          'username': username.toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Send email verification
        try {
          await user.sendEmailVerification();
          developer.log('Email verification sent successfully');
        } catch (e) {
          developer.log('Error sending email verification: $e');
          // Continue without blocking registration
        }

        await user.reload();
        _user = _auth.currentUser;
        notifyListeners();

        developer.log('User created with complete profile successfully');
        return user;
      }
    } catch (e) {
      developer.log('Error creating user with complete profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
    return null;
  }
}
