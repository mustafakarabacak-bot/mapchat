import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../home/home.dart';
import '../messages/messages_page.dart';
import '../notifications/notifications_page.dart';
import '../auth/screens/login_screen.dart';
import '../settings/settings_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _currentPageIndex = 3;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _userData = doc.data();
        });
      }
    }
  }

  void _showAccountOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.switch_account, color: Colors.black87),
                  title: const Text('Hesap Değiştir', style: TextStyle(color: Colors.black87)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Çıkış yapılırken hata: $e')),
      );
    }
  }

  String _getRandomHeaderImage() {
    final galleryImages = _userData?['galleryImages'] as List<dynamic>?;
    if (galleryImages != null && galleryImages.isNotEmpty) {
      final random = Random();
      return galleryImages[random.nextInt(galleryImages.length)];
    }
    return '';
  }

  void _showImageViewer(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black87,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    child: Image.network(
                      images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final headerImage = _getRandomHeaderImage();
    final galleryImages = _userData?['galleryImages'] as List<dynamic>? ?? [];
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // Arkaplan gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0A),
                  Color(0xFF1A1A1A),
                  Color(0xFF2A1A2A),
                ],
              ),
            ),
          ),

          // Ana içerik
          SingleChildScrollView(
            child: Column(
              children: [
                // Header - Küçültülmüş ve karartılmış
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: headerImage.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(headerImage),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: headerImage.isEmpty
                        ? const LinearGradient(
                            colors: [Color(0xFF1A1A1A), Color(0xFF2A1A2A)],
                          )
                        : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Üst bar - Sadeleştirilmiş
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              children: [
                                // Sol - Kullanıcı adı (sadece yazı)
                                GestureDetector(
                                  onTap: _showAccountOptions,
                                  child: Row(
                                    children: [
                                      Text(
                                        _userData?['username'] ?? 'Kullanıcı',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                // Sağ - Ayarlar (sadece icon)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration: Duration.zero,
                                        pageBuilder: (context, animation, secondaryAnimation) => const SettingsPage(),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Profil bilgileri - Header içinde
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Profil fotoğrafı
                                Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                      ),
                                      child: ClipOval(
                                        child: _userData?['profileImageUrl'] != null
                                            ? Image.network(
                                                _userData!['profileImageUrl'],
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: Colors.grey[400],
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 50,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              transitionDuration: Duration.zero,
                                              pageBuilder: (context, animation, secondaryAnimation) => const EditProfilePage(),
                                            ),
                                          ).then((_) => _loadUserData());
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            color: Colors.black,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // İsim - Küçük font
                                Text(
                                  '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}'.trim().isEmpty 
                                      ? 'İsim Belirtilmemiş' 
                                      : '${_userData?['firstName'] ?? ''} ${_userData?['lastName'] ?? ''}'.trim(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                
                                const SizedBox(height: 5),
                                
                                // Bio - Küçük font
                                if (_userData?['bio'] != null && _userData!['bio'].isNotEmpty)
                                  Text(
                                    _userData!['bio'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                
                                const SizedBox(height: 10),
                                
                                // Sadece doğum tarihi ve cinsiyet
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_userData?['birthDate'] != null) ...[
                                      Icon(Icons.cake, color: Colors.white70, size: 16),
                                      const SizedBox(width: 5),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format((_userData!['birthDate'] as Timestamp).toDate()),
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                    if (_userData?['birthDate'] != null && _userData?['gender'] != null)
                                      const Text(' • ', style: TextStyle(color: Colors.white70)),
                                    if (_userData?['gender'] != null) ...[
                                      Icon(Icons.person, color: Colors.white70, size: 16),
                                      const SizedBox(width: 5),
                                      Text(
                                        _userData!['gender'],
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Galeri Fotoğrafları - Kompakt tasarım
                if (galleryImages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: galleryImages.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _showImageViewer(
                                galleryImages.cast<String>(), 
                                index,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white24, width: 1),
                                ),
                                child: Image.network(
                                  galleryImages[index],
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.error,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // Alt Navigasyon - Ana sayfayla birebir aynı
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.home, 'Ana Sayfa', 0),
                      _buildNavItem(Icons.chat_bubble, 'Mesajlar', 1),
                      _buildNavItem(Icons.favorite, 'Bildirimler', 2),
                      _buildProfileNavItem(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = index == _currentPageIndex;
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            ),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) => const MessagesPage(),
            ),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) => const NotificationsPage(),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD2042D).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFD2042D) : Colors.black87,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFD2042D) : Colors.black87,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileNavItem() {
    final isSelected = _currentPageIndex == 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD2042D).withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFD2042D) : Colors.black87,
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: _userData?['profileImageUrl'] != null
                  ? Image.network(
                      _userData!['profileImageUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: isSelected 
                              ? const Color(0xFFD2042D)
                              : Colors.black87,
                          size: 14,
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      color: isSelected 
                          ? const Color(0xFFD2042D)
                          : Colors.black87,
                      size: 14,
                    ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Profil',
            style: TextStyle(
              color: isSelected 
                  ? const Color(0xFFD2042D)
                  : Colors.black87,
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
