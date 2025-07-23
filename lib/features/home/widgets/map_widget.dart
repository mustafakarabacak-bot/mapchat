import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../profile/user_profile_page.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(39.925533, 32.866287); // Ankara varsayılan
  List<Marker> _userMarkers = [];
  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _requestLocationPermission();
    if (_locationPermissionGranted) {
      await _getCurrentLocation();
      await _saveLocationToFirestore();
      await _loadActiveUsers();
    }
    setState(() {
      _isLoadingLocation = false;
    });
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    _locationPermissionGranted = true;
  }

  Future<void> _getCurrentLocation() async {
    if (!_locationPermissionGranted) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      // Haritayı sadece başlangıçta ortala
      if (mounted) {
        _mapController.move(_currentLocation, 15.0);
      }
    } catch (e) {
      print('Konum alınırken hata: $e');
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
        'location': GeoPoint(_currentLocation.latitude, _currentLocation.longitude),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Konum kaydedilirken hata: $e');
    }
  }

  Future<void> _loadActiveUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Son 5 dakika içinde aktif olan kullanıcıları getir
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('lastActive', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
          .where('location', isNotEqualTo: null)
          .get();

      List<Marker> markers = [];

      for (var doc in snapshot.docs) {
        final userData = doc.data();
        final location = userData['location'] as GeoPoint?;
        
        if (location != null) {
          final isCurrentUser = doc.id == currentUser.uid;
          
          markers.add(
            Marker(
              point: LatLng(location.latitude, location.longitude),
              width: isCurrentUser ? 60 : 50,
              height: isCurrentUser ? 60 : 50,
              child: GestureDetector(
                onTap: () {
                  if (isCurrentUser) {
                    // Kendi profiline git
                    Navigator.pushNamed(context, '/profile');
                  } else {
                    // Başka kullanıcının profiline git
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
                    border: Border.all(
                      color: isCurrentUser 
                          ? const Color(0xFFD2042D) 
                          : Colors.green,
                      width: isCurrentUser ? 4 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isCurrentUser 
                            ? const Color(0xFFD2042D) 
                            : Colors.green).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: isCurrentUser ? 26 : 21,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: isCurrentUser ? 23 : 18,
                      backgroundImage: userData['profileImageUrl'] != null
                          ? NetworkImage(userData['profileImageUrl'])
                          : null,
                      child: userData['profileImageUrl'] == null
                          ? Icon(
                              Icons.person,
                              color: const Color(0xFFD2042D),
                              size: isCurrentUser ? 25 : 20,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }

      setState(() {
        _userMarkers = markers;
      });
    } catch (e) {
      print('Aktif kullanıcılar yüklenirken hata: $e');
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
        initialZoom: 15.0,
        maxZoom: 18.0,
        minZoom: 3.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          additionalOptions: const {
            'attribution': '',
          },
        ),
        
        // Kullanıcı marker'ları
        MarkerLayer(
          markers: _userMarkers,
        ),
      ],
    );
  }
}
