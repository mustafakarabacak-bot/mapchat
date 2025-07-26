import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home.dart';
import '../notifications/notifications_page.dart';
import '../profile/profile_page.dart';
import '../profile/user_profile_page.dart';
import 'chat_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  int _currentPageIndex = 1; // Mesajlar sayfası seçili
  Map<String, dynamic>? _userData;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        final data = doc.data();
        setState(() {
          _userData = data;
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // İsim ve kullanıcı adında arama yapmak için birden fazla query kullan
      final List<QuerySnapshot> snapshots = await Future.wait([
        // Username arama
        FirebaseFirestore.instance
            .collection('users')
            .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
            .where('username', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
            .limit(5)
            .get(),
        // Name arama
        FirebaseFirestore.instance
            .collection('users')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(5)
            .get(),
      ]);

      List<Map<String, dynamic>> results = [];
      Set<String> addedUserIds = {}; // Duplicateları önlemek için

      // Her iki sonucu birleştir
      for (var snapshot in snapshots) {
        for (var doc in snapshot.docs) {
          if (doc.id != currentUser.uid && !addedUserIds.contains(doc.id)) {
            final data = doc.data() as Map<String, dynamic>;
            data['userId'] = doc.id;
            results.add(data);
            addedUserIds.add(doc.id);
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Arama hatası: $e'); // Debug için
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _startConversation(String otherUserId, Map<String, dynamic> otherUserData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Konuşma ID'sini oluştur (alfabetik sıra)
      final participants = [currentUser.uid, otherUserId];
      participants.sort();
      final conversationId = '${participants[0]}_${participants[1]}';

      // Konuşma var mı kontrol et
      final conversationDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        // Konuşma yoksa oluştur
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .set({
          'participants': participants,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Chat sayfasına git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            conversationId: conversationId,
            otherUserId: otherUserId,
            otherUserData: otherUserData,
          ),
        ),
      );

      // Arama kutusunu temizle
      _searchController.clear();
      setState(() {
        _searchQuery = '';
        _searchResults = [];
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                ],
              ),
            ),
          ),
          
          // İçerik
          SafeArea(
            child: Column(
              children: [
                // Arama Bar
                _buildSearchBar(),
                // Mesajlar Listesi
                Expanded(child: _buildMessagesList()),
              ],
            ),
          ),
          
          // Bottom Navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: _buildGlassmorphismBottomNav(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
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
            child: Column(
              children: [
                // Arama kutusu
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'İsim veya kullanıcı adı ara...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _searchUsers(value);
                    },
                  ),
                ),
                
                // Arama sonuçları
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: _isSearching
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : _searchResults.isEmpty
                            ? Column(
                                children: [
                                  Text(
                                    'Kullanıcı bulunamadı',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Aranan: "$_searchQuery"',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final user = _searchResults[index];
                                  return _buildSearchResultTile(user);
                                },
                              ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> userData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 18,
            backgroundImage: userData['profileImageUrl'] != null
                ? NetworkImage(userData['profileImageUrl'])
                : null,
            child: userData['profileImageUrl'] == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
        ),
        title: Text(
          userData['name'] ?? userData['username'] ?? 'Kullanıcı',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '@${userData['username'] ?? 'kullaniciadi'}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 20,
        ),
        onTap: () => _startConversation(userData['userId'], userData),
      ),
    );
  }

  Widget _buildMessagesList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Oturum açmanız gerekiyor',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.white54,
                ),
                SizedBox(height: 16),
                Text(
                  'Henüz mesajınız yok',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Yukarıdaki arama kutusunu kullanarak\nyeni arkadaşlar bulabilirsiniz',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Konuşmaları zamana göre sırala (client-side)
        final sortedDocs = snapshot.data!.docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final conversation = sortedDocs[index];
            final data = conversation.data() as Map<String, dynamic>;
            
            // Diğer kullanıcının ID'sini bul
            final participants = List<String>.from(data['participants']);
            final otherUserId = participants.firstWhere((id) => id != user.uid);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                return _buildConversationTile(
                  conversationId: conversation.id,
                  otherUserId: otherUserId,
                  otherUserData: userData,
                  lastMessage: data['lastMessage'] ?? '',
                  lastMessageTime: data['lastMessageTime'] as Timestamp?,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildConversationTile({
    required String conversationId,
    required String otherUserId,
    required Map<String, dynamic> otherUserData,
    required String lastMessage,
    required Timestamp? lastMessageTime,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: otherUserData['profileImageUrl'] != null
                      ? NetworkImage(otherUserData['profileImageUrl'])
                      : null,
                  child: otherUserData['profileImageUrl'] == null
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
              ),
              title: Text(
                otherUserData['name'] ?? otherUserData['username'] ?? 'Kullanıcı',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                lastMessage.isNotEmpty ? lastMessage : 'Mesaj yok',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: lastMessageTime != null
                  ? Text(
                      _formatTime(lastMessageTime),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      conversationId: conversationId,
                      otherUserId: otherUserId,
                      otherUserData: otherUserData,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphismBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
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
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = index == _currentPageIndex;
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          // Ana sayfaya git
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else if (index == 2) {
          // Bildirimler sayfasına git
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const NotificationsPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
        // index == 1 ise zaten mesajlar sayfasındayız
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? Colors.white.withOpacity(0.3)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? const Color(0xFFD2042D)
                  : Colors.black87,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
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
      ),
    );
  }

  Widget _buildProfileNavItem() {
    final isSelected = 3 == _currentPageIndex;
    return GestureDetector(
      onTap: () {
        // Profil sayfasına git
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? Colors.white.withOpacity(0.3)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFFD2042D)
                      : Colors.black87,
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
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}g';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}s';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}dk';
    } else {
      return 'şimdi';
    }
  }
}
