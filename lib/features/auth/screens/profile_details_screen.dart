import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../../home/home.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final String email;
  final String name;
  final String username;
  final String password;

  const ProfileDetailsScreen({
    super.key,
    required this.email,
    required this.name,
    required this.username,
    required this.password,
  });

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  bool _isCheckingPhone = false;
  bool _isPhoneAvailable = false;
  
  String? _selectedGender;
  DateTime? _selectedBirthDate;

  final List<String> _genders = ['Erkek', 'Kadın', 'Belirtmek İstemiyorum'];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Kullanıcının mevcut verilerini Firestore'dan çek
  Future<Map<String, dynamic>?> _getUserData() async {
    try {
      final user = _authService.user;
      if (user != null) {
        return await _authService.getUserData(user.uid);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _checkPhoneAvailability() async {
    String phone = _phoneController.text.trim();
    
    if (phone.length < 10) {
      setState(() {
        _isPhoneAvailable = false;
      });
      return;
    }

    setState(() {
      _isCheckingPhone = true;
    });

    try {
      bool isAvailable = await _authService.checkPhoneAvailability(phone);
      setState(() {
        _isPhoneAvailable = isAvailable;
        _isCheckingPhone = false;
      });
      
      if (!isAvailable) {
        _showPhoneExistsDialog();
      }
    } catch (e) {
      setState(() {
        _isCheckingPhone = false;
        _isPhoneAvailable = false;
      });
    }
  }

  void _showPhoneExistsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Telefon Kayıtlı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Bu telefon numarasına bağlı bir hesap zaten mevcut. Lütfen giriş yapmayı deneyin veya farklı bir numara kullanın.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Farklı Numara',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2042D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 yaş
      firstDate: DateTime.now().subtract(const Duration(days: 36500)), // 100 yaş
      lastDate: DateTime.now().subtract(const Duration(days: 4380)), // 12 yaş
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD2042D),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _continueToNextPage() async {
    if (_formKey.currentState!.validate() && 
        _selectedGender != null && 
        _selectedBirthDate != null &&
        _isPhoneAvailable) {
      
      setState(() {
        _isLoading = true;
      });

      try {
        // Kullanıcı detaylarını kaydet (yaş, cinsiyet, telefon)
        await _authService.updateUserDetails(
          gender: _selectedGender!,
          birthDate: _selectedBirthDate!,
          phoneNumber: _phoneController.text.trim(),
        );

        // Profili tamamlandı olarak işaretle
        await _authService.markProfileAsCompleted();

        if (mounted) {
          // Başarı mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profilin başarıyla oluşturuldu! Hoş geldin! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Ana ekrana yönlendir
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
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
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/arkaplan.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
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
                        // Progress Indicator
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Title
                        const Text(
                          'Kişisel Bilgiler',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Adım 2/2 - Son Adım!',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Profile Image Preview - Firestore'dan çek
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _getUserData(),
                          builder: (context, snapshot) {
                            String? profileImageUrl;
                            
                            if (snapshot.connectionState == ConnectionState.done && 
                                snapshot.hasData && 
                                snapshot.data != null) {
                              profileImageUrl = snapshot.data!['profileImageUrl'] as String?;
                            }
                            
                            if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                              return Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    profileImageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            } else {
                              return Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              );
                            }
                          },
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Username Display
                        Text(
                          '@${widget.username}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Form Container
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
                                      // Gender Selection
                                      DropdownButtonFormField<String>(
                                        value: _selectedGender,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedGender = newValue;
                                          });
                                        },
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        dropdownColor: const Color(0xFFD2042D),
                                        decoration: InputDecoration(
                                          labelText: 'Cinsiyet',
                                          labelStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                          hintText: 'Cinsiyetinizi seçin',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.person_outline,
                                            color: Colors.white,
                                          ),
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
                                        items: _genders.map<DropdownMenuItem<String>>((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              value,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Lütfen cinsiyetinizi seçin';
                                          }
                                          return null;
                                        },
                                      ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      // Birth Date
                                      GestureDetector(
                                        onTap: _selectBirthDate,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Doğum Tarihi',
                                                      style: TextStyle(
                                                        color: Colors.white.withOpacity(0.8),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      _selectedBirthDate != null
                                                          ? '${_formatDate(_selectedBirthDate!)} (${_calculateAge(_selectedBirthDate!)} yaş)'
                                                          : 'Doğum tarihinizi seçin',
                                                      style: TextStyle(
                                                        color: _selectedBirthDate != null
                                                            ? Colors.white
                                                            : Colors.white.withOpacity(0.5),
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                color: Colors.white.withOpacity(0.7),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      if (_selectedBirthDate != null && _calculateAge(_selectedBirthDate!) < 13)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            '13 yaşından küçük kullanıcılar kayıt olamaz',
                                            style: TextStyle(
                                              color: Colors.red[300],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      
                                      const SizedBox(height: 20),
                                      
                                      // Phone Number
                                      TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(11),
                                        ],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        onChanged: (value) {
                                          if (value.length >= 10) {
                                            _checkPhoneAvailability();
                                          } else {
                                            setState(() {
                                              _isPhoneAvailable = false;
                                            });
                                          }
                                        },
                                        decoration: InputDecoration(
                                          labelText: 'Telefon Numarası *',
                                          labelStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                          hintText: '05xxxxxxxxx',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.phone,
                                            color: Colors.white,
                                          ),
                                          suffixIcon: _isCheckingPhone
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : _phoneController.text.length >= 10
                                                  ? Icon(
                                                      _isPhoneAvailable
                                                          ? Icons.check_circle
                                                          : Icons.cancel,
                                                      color: _isPhoneAvailable
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
                                            return 'Telefon numarası zorunludur';
                                          }
                                          if (value.trim().length < 10) {
                                            return 'Geçerli bir telefon numarası girin';
                                          }
                                          if (!_isPhoneAvailable) {
                                            return 'Bu telefon numarası zaten kullanılıyor';
                                          }
                                          return null;
                                        },
                                      ),
                                      
                                      if (!_isPhoneAvailable && _phoneController.text.length >= 10 && !_isCheckingPhone)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Bu telefon numarasına bağlı hesap var',
                                            style: TextStyle(
                                              color: Colors.red[300],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Required field info
                                      Text(
                                        '* Zorunlu alan',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // Continue Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: (_selectedGender != null && 
                                               _selectedBirthDate != null && 
                                               _isPhoneAvailable && 
                                               _calculateAge(_selectedBirthDate ?? DateTime.now()) >= 13 &&
                                               !_isLoading) 
                                        ? _continueToNextPage 
                                        : null,
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
                                            'Kayıt Tamamla',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Back Button
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Geri Dön',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
