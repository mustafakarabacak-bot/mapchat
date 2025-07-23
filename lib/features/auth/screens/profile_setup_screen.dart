import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'profile_details_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String email;
  final String name;
  final String password;

  const ProfileSetupScreen({
    super.key,
    required this.email,
    required this.name,
    required this.password,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  File? _profileImage;
  Uint8List? _webImage;
  final ImagePicker _picker = ImagePicker();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _usernameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability() async {
    String username = _usernameController.text.trim().toLowerCase();
    
    if (username.length < 3) {
      if (mounted) {
        setState(() {
          _isUsernameAvailable = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingUsername = true;
      });
    }

    try {
      bool isAvailable = await _authService.checkUsernameAvailability(username);
      if (mounted) {
        setState(() {
          _isUsernameAvailable = isAvailable;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = false;
        });
      }
    }
  }

  void _onUsernameChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    if (value.length < 3) {
      if (mounted) {
        setState(() {
          _isUsernameAvailable = false;
          _isCheckingUsername = false;
        });
      }
      return;
    }
    
    // Set new timer with 500ms delay
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && value == _usernameController.text) {
        _checkUsernameAvailability();
      }
    });
  }

  Future<void> _pickProfileImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Profil Resmi Seç',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _getImage(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2042D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFD2042D).withOpacity(0.3),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Color(0xFFD2042D),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Kamera',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD2042D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _getImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2042D).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFD2042D).withOpacity(0.3),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 40,
                            color: Color(0xFFD2042D),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Galeri',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD2042D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    Navigator.pop(context);
    
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // Web için
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _webImage = bytes;
            _profileImage = null;
          });
        } else {
          // Mobile için
          setState(() {
            _profileImage = File(pickedFile.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim seçilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _continueToNextPage() async {
    if (_formKey.currentState!.validate() && _isUsernameAvailable) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? profileImageUrl;
        
        // Eğer profil resmi seçildiyse Firebase Storage'a yükle
        if (_profileImage != null || _webImage != null) {
          profileImageUrl = await _authService.uploadProfileImageBytes(
            kIsWeb ? _webImage! : await _profileImage!.readAsBytes(),
            _usernameController.text.trim(),
          );
        }

        // Sadece bu sayfanın topladığı bilgileri kaydet (username ve profil resmi)
        await _authService.updateUserProfile(
          username: _usernameController.text.trim(),
          profileImageUrl: profileImageUrl,
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileDetailsScreen(
                email: widget.email,
                name: widget.name,
                username: _usernameController.text.trim(),
                password: widget.password,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/arkaplan.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFD2042D).withOpacity(0.8),
                const Color(0xFFFF6F61).withOpacity(0.6),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: Container(
              color: Colors.black.withOpacity(0.1),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Progress Indicator (2 adım)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Title
                        const Text(
                          'Profilini Oluştur',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        Text(
                          'Adım 1/2 - Temel Bilgiler',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Profile Image Section
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _webImage != null
                                  ? Image.memory(
                                      _webImage!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                    )
                                  : _profileImage != null
                                      ? Image.file(
                                          _profileImage!,
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        )
                                      : Container(
                                          color: Colors.white.withOpacity(0.2),
                                          child: const Icon(
                                            Icons.add_a_photo,
                                            size: 40,
                                            color: Colors.white,
                                          ),
                                        ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        Text(
                          'Profil resmi ekle',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Username Input
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _usernameController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                onChanged: _onUsernameChanged,
                                decoration: InputDecoration(
                                  labelText: 'Kullanıcı Adı',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  hintText: 'Benzersiz kullanıcı adı seç',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.alternate_email,
                                    color: Colors.white,
                                  ),
                                  suffixIcon: _isCheckingUsername
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : _usernameController.text.length >= 3
                                          ? Icon(
                                              _isUsernameAvailable
                                                  ? Icons.check_circle
                                                  : Icons.cancel,
                                              color: _isUsernameAvailable
                                                  ? Colors.green
                                                  : Colors.red,
                                            )
                                          : null,
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Kullanıcı adı gerekli';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'En az 3 karakter olmalı';
                                  }
                                  if (!_isUsernameAvailable) {
                                    return 'Bu kullanıcı adı kullanılıyor';
                                  }
                                  return null;
                                },
                              ),
                              
                              if (!_isUsernameAvailable && _usernameController.text.length >= 3 && !_isCheckingUsername)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Bu kullanıcı adı zaten alınmış',
                                    style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Continue Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isUsernameAvailable && !_isLoading) ? _continueToNextPage : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD2042D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Devam Et',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
