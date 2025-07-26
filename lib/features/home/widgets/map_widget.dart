import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;
import 'dart:async';
import '../../profile/user_profile_page.dart';
import '../../messages/chat_page.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  LatLng _currentLocation =
      const LatLng(39.925533, 32.866287); // Ankara varsayılan
  List<Marker> _userMarkers = [];
  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = true;
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  Timer? _locationUpdateTimer;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    print('🗺️ MapWidget: initState çağrıldı'); // Web console için
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    developer.log('Harita initialization başlıyor...', name: 'MapWidget');
    print('🗺️ MapWidget: Harita initialization başlıyor...'); // Web console için
    try {
      await _requestLocationPermission();
      developer.log('Konum izni durumu: $_locationPermissionGranted', name: 'MapWidget');
      
      if (_locationPermissionGranted) {
        await _getCurrentLocation();
        developer.log('Mevcut konum: $_currentLocation', name: 'MapWidget');
        
        await _saveLocationToFirestore();
        developer.log('Konum Firestore\'a kaydedildi', name: 'MapWidget');
        
        _startRealtimeUpdates();
        developer.log('Gerçek zamanlı güncellemeler başlatıldı', name: 'MapWidget');
        
        _startLocationTracking();
        developer.log('Konum takibi başlatıldı', name: 'MapWidget');
      }
    } catch (e) {
      developer.log('Harita initialization hatası: $e', name: 'MapWidget');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        developer.log('Loading durumu kapatıldı', name: 'MapWidget');
      }
    }
  }

  @override
  void dispose() {
    // MapController dispose edilmeli
    _mapController.dispose();
    // Stream subscription'ları temizle
    _usersSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    developer.log('Konum izni kontrolü başlıyor...', name: 'MapWidget');
    print('🗺️ MapWidget: Konum izni kontrolü başlıyor...'); // Web console için
    try {
      // Web için özel kontrol
      if (kIsWeb) {
        developer.log('Web platformu algılandı, HTML5 Geolocation API kullanılacak', name: 'MapWidget');
        print('🗺️ MapWidget: Web platformu algılandı'); // Web console için
        // Web için basit izin kontrolü
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          developer.log('Web konum izni verildi: ${position.latitude}, ${position.longitude}', name: 'MapWidget');
          setState(() {
            _locationPermissionGranted = true;
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
          return;
        } catch (e) {
          developer.log('Web konum alma hatası: $e', name: 'MapWidget');
          setState(() {
            _locationPermissionGranted = false;
          });
          return;
        }
      }
      
      // Platform bağımsız konum izni kontrolü (mobil için)
      LocationPermission permission = await Geolocator.checkPermission();
      developer.log('Mevcut izin durumu: $permission', name: 'MapWidget');
      
      if (permission == LocationPermission.denied) {
        developer.log('İzin reddedilmiş, yeniden istenecek', name: 'MapWidget');
        permission = await Geolocator.requestPermission();
        developer.log('Yeni izin durumu: $permission', name: 'MapWidget');
      }
      
      if (permission == LocationPermission.deniedForever) {
        developer.log('Konum izni kalıcı olarak reddedildi', name: 'MapWidget');
        setState(() {
          _locationPermissionGranted = false;
        });
        return;
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        developer.log('Konum izni verildi: $permission', name: 'MapWidget');
        setState(() {
          _locationPermissionGranted = true;
        });
      }
    } catch (e) {
      developer.log('Konum izni hatası: $e', name: 'MapWidget');
      setState(() {
        _locationPermissionGranted = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    developer.log('getCurrentLocation çağrıldı, izin durumu: $_locationPermissionGranted', name: 'MapWidget');
    
    if (!_locationPermissionGranted) {
      developer.log('Konum izni yok, varsayılan konum kullanılacak', name: 'MapWidget');
      return;
    }

    try {
      developer.log('Konum alınmaya başlanıyor...', name: 'MapWidget');
      
      // Web için daha esnek ayarlar
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
        timeLimit: Duration(seconds: kIsWeb ? 15 : 5),
      );

      developer.log('Konum başarıyla alındı: ${position.latitude}, ${position.longitude}', name: 'MapWidget');

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        developer.log('Harita konumu güncellendi: $_currentLocation', name: 'MapWidget');
        
        // Haritayı sadece başlangıçta ortala
        try {
          _mapController.move(_currentLocation, 13.0);
          developer.log('Harita kamerası konuma taşındı', name: 'MapWidget');
        } catch (e) {
          developer.log('Harita kamerası taşıma hatası: $e', name: 'MapWidget');
        }
      }
    } catch (e) {
      developer.log('Konum alınırken hata: $e', name: 'MapWidget');
      
      // Hata durumunda varsayılan konumu kullan
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(39.925533, 32.866287);
        });
        
        try {
          _mapController.move(_currentLocation, 13.0);
          developer.log('Varsayılan konum kullanıldı: $_currentLocation', name: 'MapWidget');
        } catch (e) {
          developer.log('Varsayılan konum ayarlama hatası: $e', name: 'MapWidget');
        }
        
        // Kullanıcıya bilgi verin (sadece development'ta)
        if (kDebugMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Konum alınamadı: ${e.toString()}'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveLocationToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_locationPermissionGranted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'location':
            GeoPoint(_currentLocation.latitude, _currentLocation.longitude),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Konum kaydedilirken hata: $e', name: 'MapWidget');
    }
  }

  Future<void> _loadActiveUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Aktif kullanıcıları getir (sadece location varsa)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('location', isNotEqualTo: null)
          .get();

      List<Marker> markers = [];
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));

      for (var doc in snapshot.docs) {
        final userData = doc.data();
        final location = userData['location'] as GeoPoint?;
        final lastActive = userData['lastActive'] as Timestamp?;
        
        // Client-side filtering için son 5 dakika kontrolü
        if (lastActive != null && lastActive.toDate().isAfter(fiveMinutesAgo) && location != null) {
          final isCurrentUser = doc.id == currentUser.uid;
          final distance = _calculateDistance(location);

          markers.add(
            Marker(
              point: LatLng(location.latitude, location.longitude),
              width: isCurrentUser ? 60 : 50,
              height: isCurrentUser ? 60 : 50,
              child: _buildAdvancedMarker(userData, doc.id, isCurrentUser, distance),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _userMarkers = markers;
        });
      }
    } catch (e) {
      developer.log('Aktif kullanıcılar yüklenirken hata: $e', name: 'MapWidget');
    }
  }

  // Gerçek zamanlı güncellemeler
  void _startRealtimeUpdates() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      developer.log('Kullanıcı giriş yapmamış, gerçek zamanlı güncellemeler başlatılamadı', name: 'MapWidget');
      return;
    }

    developer.log('Gerçek zamanlı güncellemeler için Firestore stream başlatılıyor...', name: 'MapWidget');
    
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('location', isNotEqualTo: null)
        .snapshots()
        .listen((snapshot) {
      developer.log('Firestore snapshot alındı: ${snapshot.docs.length} kullanıcı', name: 'MapWidget');
      _updateMarkersFromSnapshot(snapshot);
    }, onError: (error) {
      developer.log('Gerçek zamanlı güncelleme hatası: $error', name: 'MapWidget');
    });
  }

  void _updateMarkersFromSnapshot(QuerySnapshot snapshot) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    developer.log('Marker güncelleme başlıyor: ${snapshot.docs.length} döküman', name: 'MapWidget');
    
    List<Marker> markers = [];
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));

    for (var doc in snapshot.docs) {
      final userData = doc.data() as Map<String, dynamic>;
      final location = userData['location'] as GeoPoint?;
      final lastActive = userData['lastActive'] as Timestamp?;
      
      developer.log('Kullanıcı: ${doc.id}, Location: $location, LastActive: $lastActive', name: 'MapWidget');
      
      if (lastActive != null && lastActive.toDate().isAfter(fiveMinutesAgo) && location != null) {
        final isCurrentUser = doc.id == currentUser.uid;
        final distance = _calculateDistance(location);

        developer.log('Aktif kullanıcı ekleniyor: ${userData['username']} - $distance m uzaklıkta', name: 'MapWidget');

        markers.add(
          Marker(
            point: LatLng(location.latitude, location.longitude),
            width: isCurrentUser ? 60 : 50,
            height: isCurrentUser ? 60 : 50,
            child: _buildAdvancedMarker(userData, doc.id, isCurrentUser, distance),
          ),
        );
      } else {
        developer.log('Kullanıcı aktif değil: ${userData['username']}', name: 'MapWidget');
      }
    }

    developer.log('Toplam ${markers.length} marker oluşturuldu', name: 'MapWidget');

    if (mounted) {
      setState(() {
        _userMarkers = markers;
      });
      developer.log('UI güncellendi: ${_userMarkers.length} marker görüntüleniyor', name: 'MapWidget');
    }
  }

  // Konum takibi
  void _startLocationTracking() {
    if (!_locationPermissionGranted) return;

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateCurrentLocation();
    });
  }

  Future<void> _updateCurrentLocation() async {
    if (!_locationPermissionGranted) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final newLocation = LatLng(position.latitude, position.longitude);
      final distance = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );

      // Sadece 50m+ hareket varsa güncelle (battery saving)
      if (distance >= 50) {
        setState(() {
          _currentLocation = newLocation;
        });
        await _saveLocationToFirestore();
      }
    } catch (e) {
      developer.log('Konum güncelleme hatası: $e', name: 'MapWidget');
    }
  }

  double _calculateDistance(GeoPoint userLocation) {
    return Geolocator.distanceBetween(
      _currentLocation.latitude,
      _currentLocation.longitude,
      userLocation.latitude,
      userLocation.longitude,
    );
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  Widget _buildAdvancedMarker(Map<String, dynamic> userData, String userId, bool isCurrentUser, double distance) {
    final username = userData['username'] ?? 'Anonim';
    final profileImageUrl = userData['profileImageUrl'];
    final lastActive = userData['lastActive'] as Timestamp?;
    
    return GestureDetector(
      onTap: () => _showUserBottomSheet(userData, userId, isCurrentUser),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow effect for current user
          if (isCurrentUser)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD2042D).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          
          // Main marker
          Container(
            width: isCurrentUser ? 60 : 50,
            height: isCurrentUser ? 60 : 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentUser ? const Color(0xFFD2042D) : Colors.green,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: profileImageUrl != null
                  ? Image.network(
                      profileImageUrl,
                      fit: BoxFit.cover,
                      width: isCurrentUser ? 60 : 50,
                      height: isCurrentUser ? 60 : 50,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: isCurrentUser ? const Color(0xFFD2042D) : Colors.green,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: isCurrentUser ? 24 : 20,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: isCurrentUser ? const Color(0xFFD2042D) : Colors.green,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: isCurrentUser ? 24 : 20,
                          ),
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      color: Colors.white,
                      size: isCurrentUser ? 24 : 20,
                    ),
            ),
          ),
          
          // Online indicator
          if (!isCurrentUser && lastActive != null)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isUserOnline(lastActive) ? Colors.green : Colors.orange,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isUserOnline(Timestamp lastActive) {
    final now = DateTime.now();
    final lastActiveTime = lastActive.toDate();
    return now.difference(lastActiveTime).inMinutes < 2; // 2 dakika içinde online
  }

  void _showUserBottomSheet(Map<String, dynamic> userData, String userId, bool isCurrentUser) {
    final username = userData['username'] ?? 'Anonim';
    final name = userData['name'] ?? '';
    final profileImageUrl = userData['profileImageUrl'];
    final location = userData['location'] as GeoPoint?;
    final distance = location != null ? _calculateDistance(location) : 0.0;
    final lastActive = userData['lastActive'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Profile info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isCurrentUser ? const Color(0xFFD2042D) : Colors.green,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                  child: profileImageUrl == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (name.isNotEmpty)
                        Text(
                          name,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      Text(
                        '${_formatDistance(distance)} uzaklıkta',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (lastActive != null)
                        Text(
                          _isUserOnline(lastActive) ? 'Çevrimiçi' : 'Son görülme: ${_formatLastSeen(lastActive)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isUserOnline(lastActive) ? Colors.green : Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            if (!isCurrentUser) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToChat(userId, username);
                      },
                      icon: const Icon(Icons.message),
                      label: const Text('Mesaj Gönder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD2042D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToProfile(userId, username);
                      },
                      icon: const Icon(Icons.person),
                      label: const Text('Profil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD2042D),
                        side: const BorderSide(color: Color(0xFFD2042D)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
                icon: const Icon(Icons.settings),
                label: const Text('Profilim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2042D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(Timestamp lastActive) {
    final now = DateTime.now();
    final lastActiveTime = lastActive.toDate();
    final difference = now.difference(lastActiveTime);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inDays} gün önce';
    }
  }

  void _navigateToChat(String userId, String username) {
    // Conversation ID oluştur
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    
    final conversationId = _generateConversationId(currentUserId, userId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversationId: conversationId,
          otherUserId: userId,
          otherUserData: {'username': username, 'name': username},
        ),
      ),
    );
  }

  String _generateConversationId(String userId1, String userId2) {
    // Consistent conversation ID generation
    List<String> users = [userId1, userId2];
    users.sort();
    return users.join('_');
  }

  void _navigateToProfile(String userId, String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          userId: userId,
          username: username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocation) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD2042D)),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 13.0,
            maxZoom: 17.0,
            minZoom: 8.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            keepAlive: true,
            backgroundColor: const Color(0xFF1a1a1a),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c'],
              additionalOptions: const {
                'attribution': '',
              },
              maxZoom: 17,
              retinaMode: false,
              tileSize: 256,
              tileProvider: NetworkTileProvider(),
              maxNativeZoom: 17,
              errorTileCallback: (tile, error, stackTrace) {
                developer.log('Tile yükleme hatası: $error', name: 'MapWidget');
              },
            ),
            MarkerLayer(
              markers: _userMarkers,
              rotate: false,
            ),
          ],
        ),
        
        // Konumuma git butonu
        Positioned(
          right: 16,
          bottom: 80,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFD2042D),
            onPressed: _goToMyLocation,
            child: const Icon(Icons.my_location),
          ),
        ),

        // Aktif kullanıcı sayısı
        Positioned(
          left: 16,
          bottom: 80,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_userMarkers.length} aktif',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _goToMyLocation() {
    if (_locationPermissionGranted) {
      _mapController.move(_currentLocation, 15.0);
    }
  }
}
