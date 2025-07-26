import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;
import 'dart:async';
import '../../profile/user_profile_page.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await _requestLocationPermission();
      if (_locationPermissionGranted) {
        await _getCurrentLocation();
        await _saveLocationToFirestore();
        await _loadActiveUsers();
      }
    } catch (e) {
      developer.log('Harita initialization hatası: $e', name: 'MapWidget');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Platform bağımsız konum izni kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
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
    if (!_locationPermissionGranted) return;

    try {
      // Platform bağımsız konum alma
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        // Haritayı sadece başlangıçta ortala
        _mapController.move(_currentLocation, 13.0);
      }
    } catch (e) {
      developer.log('Konum alınırken hata: $e', name: 'MapWidget');
      // Hata durumunda Ankara koordinatlarını kullan
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(39.925533, 32.866287);
        });
        _mapController.move(_currentLocation, 13.0);
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

          markers.add(
            Marker(
              point: LatLng(location.latitude, location.longitude),
              width: isCurrentUser ? 50 : 40, // Boyut küçültüldü
              height: isCurrentUser ? 50 : 40,
              child: GestureDetector(
                onTap: () {
                  if (isCurrentUser) {
                    Navigator.pushNamed(context, '/profile');
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfilePage(
                          userId: doc.id,
                          username: userData['username'],
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentUser
                        ? const Color(0xFFD2042D)
                        : Colors.green,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: userData['profileImageUrl'] != null
                        ? Image.network(
                            userData['profileImageUrl'],
                            fit: BoxFit.cover,
                            // Web ve mobil performans için cache ve boyut ayarları
                            cacheWidth: isCurrentUser ? 50 : 40,
                            cacheHeight: isCurrentUser ? 50 : 40,
                            // Hızlı yükleme için optimizasyon
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: isCurrentUser
                                    ? const Color(0xFFD2042D)
                                    : Colors.green,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: isCurrentUser ? 20 : 16,
                                ),
                              );
                            },
                            // Hata durumu - profil özelliklerini koruyoruz
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: isCurrentUser
                                    ? const Color(0xFFD2042D)
                                    : Colors.green,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: isCurrentUser ? 20 : 16,
                                ),
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            color: Colors.white,
                            size: isCurrentUser ? 20 : 16,
                          ),
                  ),
                ),
              ),
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

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation,
        initialZoom: 13.0, // Daha düşük başlangıç zoom
        maxZoom: 17.0, // Max zoom artırıldı biraz
        minZoom: 8.0, // Min zoom düşürüldü
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        // Web ve mobil performans için
        keepAlive: true,
        // Arka plan rengi - harita yüklenene kadar
        backgroundColor: const Color(0xFF1a1a1a),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c'],
          additionalOptions: const {
            'attribution': '',
          },
          // Web ve mobil performans optimizasyonları
          maxZoom: 17,
          retinaMode: false, // Performans için kapalı
          tileSize: 256,
          // Hızlı yükleme için
          tileProvider: NetworkTileProvider(),
          // Cache ayarları
          maxNativeZoom: 17,
          // Error handling
          errorTileCallback: (tile, error, stackTrace) {
            developer.log('Tile yükleme hatası: $error', name: 'MapWidget');
          },
        ),

        // Kullanıcı marker'ları - optimize edilmiş
        MarkerLayer(
          markers: _userMarkers,
          // Performans için rotate disabled
          rotate: false,
        ),
      ],
    );
  }
}
