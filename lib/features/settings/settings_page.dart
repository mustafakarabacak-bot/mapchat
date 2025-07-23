import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/screens/login_screen.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ayarlar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('Hesap'),
          const SizedBox(height: 15),
          
          _buildSettingsItem(
            icon: Icons.person,
            title: 'Hesap Bilgileri',
            subtitle: 'Kişisel bilgilerinizi düzenleyin',
            onTap: () {
              // Edit profile sayfasına yönlendirme
            },
          ),
          
          _buildSettingsItem(
            icon: Icons.security,
            title: 'Gizlilik',
            subtitle: 'Gizlilik ayarlarınız',
            onTap: () {
              // Gizlilik ayarları
            },
          ),
          
          _buildSettingsItem(
            icon: Icons.notifications,
            title: 'Bildirimler',
            subtitle: 'Bildirim tercihleriniz',
            onTap: () {
              // Bildirim ayarları
            },
          ),
          
          const SizedBox(height: 30),
          _buildSectionTitle('Uygulama'),
          const SizedBox(height: 15),
          
          _buildSettingsItem(
            icon: Icons.palette,
            title: 'Tema',
            subtitle: 'Uygulama temasını değiştirin',
            onTap: () {
              // Tema ayarları
            },
          ),
          
          _buildSettingsItem(
            icon: Icons.language,
            title: 'Dil',
            subtitle: 'Uygulama dilini değiştirin',
            onTap: () {
              // Dil ayarları
            },
          ),
          
          _buildSettingsItem(
            icon: Icons.storage,
            title: 'Depolama',
            subtitle: 'Önbellek ve depolama yönetimi',
            onTap: () {
              // Depolama ayarları
            },
          ),
          
          const SizedBox(height: 30),
          _buildSectionTitle('Destek'),
          const SizedBox(height: 15),
          
          _buildSettingsItem(
            icon: Icons.help,
            title: 'Yardım',
            subtitle: 'SSS ve yardım merkezi',
            onTap: () {
              // Yardım sayfası
            },
          ),
          
          _buildSettingsItem(
            icon: Icons.feedback,
            title: 'Geri Bildirim',
            subtitle: 'Görüş ve önerilerinizi paylaşın',
            onTap: () {
              // Geri bildirim
            },
          ),
          
          _buildSettingsItem(
            icon: Icons.info,
            title: 'Hakkında',
            subtitle: 'Uygulama bilgileri ve sürüm',
            onTap: () {
              // Hakkında sayfası
            },
          ),
          
          const SizedBox(height: 30),
          
          // Çıkış Yap Butonu
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: () => _logout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                ),
              ),
              child: const Text(
                'Çıkış Yap',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ListTile(
              onTap: onTap,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.pinkAccent,
                  size: 24,
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
