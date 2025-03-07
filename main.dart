import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'login.dart'; 
import 'signup.dart'; 
import 'notification_service.dart';
import 'about_page.dart';
import 'account_settings.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure binding is initialized
  await Firebase.initializeApp(); // Initialize Firebase
  await Permission.notification.request();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fuely', // Set the app title
      theme: ThemeData(
        primarySwatch: Colors.blue, // Set the primary color theme
      ),
      initialRoute: '/', // Set the initial route
      routes: {
        '/': (context) => const LoginPage(), // Start with the LoginPage
        '/signup': (context) => const SignUpPage(), // Route for SignUpPage
        '/about': (context) => AboutPage(), // Add route for AboutPage
      },
    );
  }
}


class AccountSettingsPage extends StatefulWidget {
  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  String username = 'Loading...'; // Default value
  String email = 'Loading...'; // Default value

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Fetch user data on initialization
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser ;
    if (user != null) {
      DatabaseEvent snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').once();
      if (snapshot.snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          username = userData['username'] ?? 'Unknown User';
          email = userData['email'] ?? 'Unknown Email';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccountSettings(
      onVehicleInfoUpdated: (String updatedInfo) {
        print(updatedInfo);
      },
      auth: FirebaseAuth.instance,
      username: username, // Pass the fetched username
      email: email, // Pass the fetched email
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class Place {
  final String description;
  final String placeId;

  Place({required this.description, required this.placeId});

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      description: json['display_name'] ?? 'Unknown Place',  // Default fallback for null description
      placeId: json['place_id']?.toString() ?? 'Unknown',    // Default fallback for null place_id
    );
  }
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();
  List<String> _suggestions = []; // Daftar saran
  List<String> _allItems = ['Item 1', 'Item 2', 'Item 3']; // Semua item untuk pencarian

  @override
  void initState() {
    super.initState();

    // Tambahkan listener untuk mengawasi perubahan teks
    _searchController.addListener(() {
      setState(() {
        // Jika teks kosong, kosongkan saran
        if (_searchController.text.isEmpty) {
          _suggestions.clear();
        } else {
          // Filter saran berdasarkan input
          _suggestions = _allItems
              .where((item) => item.toLowerCase().contains(_searchController.text.toLowerCase()))
              .toList();
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // Jangan lupa untuk membuang controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Page'),
      ),
      body: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search...',
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_suggestions[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _MapPageState extends State<MapPage> {
  TextEditingController _searchController = TextEditingController();
  List<Place> _places = []; // List to store fetched places
  late GoogleMapController _mapController;
  LatLng? _currentLocation;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String _totalDistance = '';
  String _fuelNeeded = '';
  String vehicleInfo = '';
  Timer? _locationUpdateTimer; // Timer for location updates
  final NotificationService notificationService = NotificationService();
  bool _notificationsEnabled = false;
  Offset _dragPosition = Offset(175, 80);
  bool _isDarkTheme = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final String _lightMapStyle = '[]';
  final String _darkMapStyle = '''
  [
    {
      "featureType": "all",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "featureType": "all",
      "elementType": "labels.icon",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#000000"
        }
      ]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#000000"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#ffffff"
        }
      ]
    }
  ]''';

// Fungsi untuk mengupdate informasi kendaraan
  void updateVehicleInfo(String newInfo) {
    setState(() {
      vehicleInfo = newInfo; // Memperbarui informasi kendaraan
    });
  }

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _fetchUserData();
    _startLocationUpdates(); 
  }

  
  // Function to start periodic location updates
  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 600), (timer) {
      _getCurrentLocation(); // Fetch current location every 5 seconds
    });
  }

  // Update the current location and the marker
  void _updateCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
      setState(() {
        _markers.removeWhere((marker) => marker.markerId.value == 'currentLocationMarker'); // Remove old marker
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocationMarker'),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
        );
      });
    }
  }


  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser ;
    if (user != null) {
      DatabaseEvent snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').once();
      if (snapshot.snapshot.value != null) {
        final userData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          vehicleInfo = 'Kendaraan: ${userData['vehicleType'] ?? 'Tidak ada'}\n'
                        'Jenis Bensin: ${userData['fuelType'] ?? 'Tidak ada'}\n'
                        'Jumlah Bahan Bakar: ${userData['fuelAmount'] ?? '0'} L';
        });
      }
    }
  }
  
  Future<void> _checkAndRequestPermissions() async {
    var status = await Permission.location.status;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.location.request();
    }

    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Location permission is required to use this feature.')),
      );
    }
  }

  Future<Position> getCurrentLocation() async {
  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
  return position;
}

  // Modify the existing _getCurrentLocation function to call _updateCurrentLocation
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _updateCurrentLocation(); // Update the map and marker with new location
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

Future<Map<String, dynamic>> _fetchRoute(LatLng start, LatLng end) async {
  final url =
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson';

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
    final double distance = data['routes'][0]['distance'];

    return {
      'routePoints': coordinates.map((coord) => LatLng(coord[1], coord[0])).toList(),
      'distance': distance,
    };
  } else {
    print('Error fetching route: ${response.body}');
    throw Exception('Failed to load route');
  }
}


  List<LatLng> simplifyRoutePoints(List<LatLng> points, {int maxPoints = 10}) {
    if (points.length <= maxPoints) return points; // No need to simplify

    double step = points.length / maxPoints;
    List<LatLng> simplifiedPoints = [];

    for (int i = 0; i < points.length; i += step.round()) {
      simplifiedPoints.add(points[i]);
    }

    return simplifiedPoints;
  }

  void _updateMap(LatLng tappedPoint) async {
  if (_markers.length < 2) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('marker${_markers.length}'),
          position: tappedPoint,
          infoWindow: InfoWindow(title: 'Location ${_markers.length + 1}'),
        ),
      );
    });

    if (_markers.length == 2) {
      LatLng start = _markers.first.position;
      LatLng end = _markers.last.position;

      try {
        var routeData = await _fetchRoute(start, end); 
        double distance = double.parse(routeData['distance'].toString()) / 1000; // Convert to kilometers
        List<LatLng> routePoints = routeData['routePoints']; 

        // Mendapatkan data pengguna untuk efisiensi bahan bakar
        final user = FirebaseAuth.instance.currentUser  ;
        if (user != null) {
          DatabaseEvent snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').once();
          if (snapshot.snapshot.value != null) {
            final userData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
            String? selectedFuelType = userData['fuelType']; // Ambil jenis bahan bakar yang dipilih
            String? selectedVehicleType = userData['vehicleType']; // Ambil jenis kendaraan yang dipilih

            // Menentukan efisiensi bahan bakar berdasarkan jenis yang dipilih
            double fuelEfficiency; 
            if (selectedVehicleType == 'Daihatsu Ayla') { 
                fuelEfficiency = selectedFuelType == 'Pertalite' ? 16.0 : 21.0; 
              } else if (selectedVehicleType == 'Honda Vario 160') { 
                fuelEfficiency = 50.0; 
              } else if (selectedVehicleType == 'Daihatsu Xenia') { 
                fuelEfficiency = selectedFuelType == 'Pertalite' ? 15.0 : 13.0; 
              } else if (selectedVehicleType == 'Toyota Avanza') { 
                fuelEfficiency = selectedFuelType == 'Pertalite' ? 15.0 : 14.0; 
              } else if (selectedVehicleType == 'Yamaha NMAX') { 
                fuelEfficiency = 39.0; 
              } else if (selectedVehicleType == 'Honda Beat') { 
                fuelEfficiency = 55.0; 
              } else { 
                fuelEfficiency = 20.0; // Default if not specified 
              } 

            // Menghitung bahan bakar yang dibutuhkan berdasarkan jarak
            if (distance > 0) {
              double fuelNeeded = distance / fuelEfficiency; // Fuel needed in liters
              setState(() { 
                _totalDistance = 'Distance: ${distance.toStringAsFixed(2)} KM'; 
                _fuelNeeded = 'Fuel Needed: ${fuelNeeded.toStringAsFixed(3)} Liters'; 

                // Menambahkan poligon biru
                _polylines.add(
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: routePoints,
                    color: Colors.blue,
                    width: 10,
                  ),
                );

                // Menghitung sisa bahan bakar dan jarak yang dapat ditempuh
                double remainingFuel = double.parse((userData['fuelAmount'] ?? 0.0).toString()); // Pastikan sisa bahan bakar adalah double

                List<LatLng> orangeRoutePoints = [];
                double totalFuelNeeded = 0.0; // Track total fuel needed for the orange route

                // Only proceed if there is enough fuel for the route
                if (remainingFuel <= 0) {
                  // Not enough fuel to proceed, do not add orange route
                  return; // Exit early
                }

                for (int i = 0; i < routePoints.length - 1; i++) {
                  double segmentDistance = Geolocator.distanceBetween(
                    routePoints[i].latitude,
                    routePoints[i].longitude,
                    routePoints[i + 1].latitude,
                    routePoints[i + 1].longitude,
                  );

                  // Calculate fuel needed for this segment
                  double fuelForSegment = segmentDistance / 1000 / fuelEfficiency; // Convert distance to km and calculate fuel needed

                  // Check if we have enough fuel for this segment
                  if (totalFuelNeeded + fuelForSegment <= remainingFuel) {
                    orangeRoutePoints.add(routePoints[i]);
                    totalFuelNeeded += fuelForSegment; // Accumulate the fuel needed for the segment
                  } else {
                    // If not enough fuel, add the last point and break
                    orangeRoutePoints.add(routePoints[i + 1]);
                    break;
                  }
                }

                // Menambahkan poligon oranye hanya jika ada cukup bahan bakar
                if (orangeRoutePoints.isNotEmpty) {
                  _polylines.add(
                    Polyline(
                      polylineId: const PolylineId('orangeRoute'),
                      points: orangeRoutePoints,
                      color: Colors.orange,
                      width: 5,
                    ),
                  );
                }
              });

              // Show notification
              await notificationService.showDistanceAndFuelNotification(_totalDistance, _fuelNeeded);
            } else {
              // Menangani kasus di mana jarak tidak valid
              setState(() {
                _totalDistance = 'Distance: 0 KM (0 meters)';
                _fuelNeeded = 'Fuel Needed: 0 Liters';
              });
            }
          }
        }
      } catch (e) {
        print('Error fetching route: $e');
      }
      // Menggerakkan kamera ke lokasi akhir
      _mapController.animateCamera(CameraUpdate.newLatLng(end));
    }
  }
}

Future<void> _fetchPlaces(String query) async {
  final url =
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5';
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('No places found for query: $query');
        return;
      }

      setState(() {
        _places = data.map((place) {
          return Place.fromJson({
            'display_name': place['display_name'] ?? 'Unknown Place',  // Handle missing display_name
            'place_id': place['place_id']?.toString() ?? 'Unknown',     // Handle missing place_id
          });
        }).toList();
      });
    } else {
      print('Failed to fetch places: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching places: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching places: $e')),
    );
  }
}

void _goToPlace(String placeName) async {
  final url =
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(placeName)}&format=json&addressdetails=1&limit=1';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      if (data.isEmpty) {
        print('No results found for place: $placeName');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No results found for place: $placeName')),
        );
        return;
      }

      final location = data[0];
      final lat = location['lat'] ?? '0.0'; // Default fallback for missing lat
      final lng = location['lon'] ?? '0.0'; // Default fallback for missing lon

      // Check for valid lat/lng values
      if (lat == '0.0' || lng == '0.0') {
        print('Invalid coordinates for place: $placeName');
        return;
      }

      final tappedPoint = LatLng(double.parse(lat), double.parse(lng));

      // Update the markers and perform route calculations
      if (_markers.length < 2) {
        setState(() {
          _markers.add(
            Marker(
              markerId: MarkerId('marker${_markers.length}'),
              position: tappedPoint,
              infoWindow: InfoWindow(title: 'Location ${_markers.length + 1}'),
            ),
          );
        });

        if (_markers.length == 2) {
          LatLng start = _markers.first.position;
          LatLng end = _markers.last.position;

          try {
            var routeData = await _fetchRoute(start, end);
            double distance = double.parse(routeData['distance'].toString()) / 1000; // Convert to kilometers
            List<LatLng> routePoints = routeData['routePoints'];

            // Mendapatkan data pengguna untuk efisiensi bahan bakar
            final user = FirebaseAuth.instance.currentUser ;
            if (user != null) {
              DatabaseEvent snapshot = await FirebaseDatabase.instance.ref('users/${user.uid}').once();
              if (snapshot.snapshot.value != null) {
                final userData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
                String? selectedFuelType = userData['fuelType']; // Ambil jenis bahan bakar yang dipilih
                String? selectedVehicleType = userData['vehicleType']; // Ambil jenis kendaraan yang dipilih

                // Menentukan efisiensi bahan bakar berdasarkan jenis yang dipilih
                double fuelEfficiency;
                if (selectedVehicleType == 'Daihatsu Ayla') { 
                  fuelEfficiency = selectedFuelType == 'Pertalite' ? 21.0 : 16.0; 
                } else if (selectedVehicleType == 'Honda Vario 160') { 
                  fuelEfficiency = 50.0; 
                } else if (selectedVehicleType == 'Daihatsu Xenia') { 
                  fuelEfficiency = selectedFuelType == 'Pertalite' ? 15.0 : 13.0; 
                } else if (selectedVehicleType == 'Toyota Avanza') { 
                  fuelEfficiency = selectedFuelType == 'Pertalite' ? 15.0 : 14.0; 
                } else if (selectedVehicleType == 'Yamaha NMAX') { 
                  fuelEfficiency = 39.0; 
                } else if (selectedVehicleType == 'Honda Beat') { 
                  fuelEfficiency = 55.0; 
                } else { 
                  fuelEfficiency = 20.0; // Default if not specified 
} 

                // Menghitung bahan bakar yang dibutuhkan berdasarkan jarak
                if (distance > 0) {
                  double fuelNeeded = distance / fuelEfficiency; // Fuel needed in liters
                  setState(() async {
                    _totalDistance = 'Distance: ${distance.toStringAsFixed(2)} KM';
                    _fuelNeeded = 'Fuel Needed: ${fuelNeeded.toStringAsFixed(3)} Liters';


                    // Menambahkan poligon biru
                    _polylines.add(
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: routePoints,
                        color: Colors.blue,
                        width: 10,
                      ),
                    );

                    // Menghitung sisa bahan bakar dan jarak yang dapat ditempuh
                    double remainingFuel = double.parse((userData['fuelAmount'] ?? 0.0).toString()); // Pastikan sisa bahan bakar adalah double
                    double maxDistance = remainingFuel * fuelEfficiency * 1000; // Jarak maksimum dalam meter

                    // Jika jarak maksimum lebih kecil dari jarak total, kita perlu memotong routePoints
                    List<LatLng> orangeRoutePoints = [];
                    double accumulatedDistance = 0.0;

                    for (int i = 0; i < routePoints.length - 1; i++) {
                      double segmentDistance = Geolocator.distanceBetween(
                        routePoints[i].latitude,
                        routePoints[i].longitude,
                        routePoints[i + 1].latitude,
                        routePoints[i + 1].longitude,
                      );

                      if (accumulatedDistance + segmentDistance <= maxDistance) {
                        orangeRoutePoints.add(routePoints[i]);
                        accumulatedDistance += segmentDistance;
                      } else {
                        // Jika sudah melebihi sisa bahan bakar, tambahkan titik terakhir
                        orangeRoutePoints.add(routePoints[i + 1]);
                        break;
                      }
                    }

                    // Menambahkan poligon oranye
                    _polylines.add(
                      Polyline(
                        polylineId: const PolylineId('orangeRoute'),
                        points: orangeRoutePoints,
                        color: Colors.orange,
                        width: 5,
                      ),
                    );
                    // Show notification
                    await notificationService.showDistanceAndFuelNotification(_totalDistance, _fuelNeeded);
                  });
                } else {
                  // Menangani kasus di mana jarak tidak valid
                  setState(() {
                    _totalDistance = 'Distance: 0 KM (0 meters)';
                    _fuelNeeded = 'Fuel Needed: 0 Liters';
                  });
                }
              }
            }
          } catch (e) {
            print('Error fetching route: $e');
          }
          // Menggerakkan kamera ke lokasi akhir
          _mapController.animateCamera(CameraUpdate.newLatLng(end));
        }
      }
    } else {
      print('Failed to fetch place: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch place: ${response.body}')),
      );
    }
  } catch (e) {
    print('Error fetching place: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching place: $e')),
    );
  }
}



  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
      _mapController.setMapStyle(_isDarkTheme ? _darkMapStyle : _lightMapStyle);
    });
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    key: _scaffoldKey,
    appBar: AppBar(
      title: Text(
        'Fuely',
        style: TextStyle(
          color: Colors.blue, // Keep text color blue in both modes
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: _isDarkTheme ? Colors.grey[850] : Colors.blue[900], // Gray in dark mode, blue in light mode
      flexibleSpace: _isDarkTheme
          ? null // No gradient in dark mode
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[900]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
      actions: [
        IconButton(
          icon: Icon(_isDarkTheme ? Icons.wb_sunny : Icons.nights_stay),
          onPressed: _toggleTheme,
        ),
      ],
    ),
    drawer: Drawer(
      child: Container(
        color: _isDarkTheme ? Colors.black : Colors.white, // Set the drawer background color
        child: Column(
          children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: _isDarkTheme ? Colors.grey[850] : Colors.blue[900], // Change background color based on theme
            ),
            child: Text(
              'Settings',
              style: TextStyle(
                 color: _isDarkTheme ? Colors.blue[900] : Colors.white, // Keep text color blue regardless of theme
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: <Widget>[
                _buildIconMenuItem(Icons.color_lens, 'Change Theme', () {
                  _toggleTheme();
                  Navigator.pop(context);
                }),
                _buildIconMenuItem(Icons.account_circle, 'Account Settings', () { 
                  final user = FirebaseAuth.instance.currentUser ;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountSettings(
                          onVehicleInfoUpdated: updateVehicleInfo,
                          auth: FirebaseAuth.instance, // Pass the FirebaseAuth instance
                          username: user?.displayName, // Pass the username (if available)
                          email: user?.email, // Pass the email (if available)
                    )),
                  );
                }),
                _buildIconMenuItem(Icons.info, 'About', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutPage()),
                  );
                }),
                _buildIconMenuItem(
                  _notificationsEnabled ? Icons.notifications : Icons.notifications_off,
                  'Notifications',
                  () async {
                    await notificationService.toggleNotifications();
                    setState(() {
                      _notificationsEnabled = notificationService.areNotificationsEnabled();
                    });
                    Navigator.pop(context);
                    }
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    
    body: Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search places',
                      hintStyle: TextStyle(color: Colors.black54),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue[900]!, width: 2),
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.blue[900]),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _fetchPlaces(value);
                      } else {
                        setState(() {
                          _places.clear();
                        });
                      }
                    },
                  ),
                  if (_places.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(
                        maxHeight: 150,
                      ),
                      child: ListView.builder(
                        itemCount: _places.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            title: Text(
                              _places[index].description,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            onTap: () {
                              _goToPlace(_places[index].description);
                              setState(() {
                                _places.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  _mapController.setMapStyle(_isDarkTheme ? _darkMapStyle : _lightMapStyle);
                },
                onTap: _updateMap,
                markers: Set<Marker>.of(_markers),
                polylines: Set<Polyline>.of(_polylines),
                initialCameraPosition: const CameraPosition(
                  target: LatLng(1.264637, 124.887367),
                  zoom: 15,
                ),
              ),
            ),
          Container(
          color: Colors.white, // Gray in dark mode, white in light mode
          child: Padding(
            padding: const EdgeInsets.all(1.1),
            child: Column(
              children: [
              Text(
                  _fuelNeeded,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange, // Change the color to orange
                  ),
                ),
                Text(
                  _totalDistance,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900], // Text color remains the same
                  ),
                ),
              ],
            ),
          ),
        ),
            ElevatedButton(
              onPressed: _removeLastMarker,
              child: const Text('Remove Last Marker'),
              style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.blue[900],
              ),
            ),
          ],
        ),
        Positioned(
          top: _dragPosition.dy,
          left: _dragPosition.dx,
          child: Draggable(
            feedback: Material(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  vehicleInfo,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            childWhenDragging: Container(), // Placeholder when dragging
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  // Update position based on drag
                  _dragPosition += details.delta;
                });
              },
              onPanEnd: (details) {
                // No need to do anything here, position is already updated
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  vehicleInfo,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          left: 20,
          child: FloatingActionButton(
            onPressed: _goToCurrentLocation,
            child: const Icon(Icons.my_location),
            tooltip: 'Current Location',
            backgroundColor: Colors.blue[900],
          ),
        ),
      ],
    ),
  );
}

Widget _buildIconMenuItem(IconData icon, String title, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Card(
      elevation: 4,
      margin: const EdgeInsets.all(8.0),
      color: _isDarkTheme ? Colors.grey[850] : Colors.white, // Change card color based on theme
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: 40,
            color: Colors.blue[900], // Keep icon color blue regardless of theme
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blue[900], // Keep text color blue regardless of theme
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}



void _goToCurrentLocation() async {
  if (_currentLocation != null) {
    // Remove existing marker if it exists
    _markers.removeWhere((marker) => marker.markerId.value == 'currentLocationMarker');

    // Add new marker for current location
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocationMarker'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Current Location'),
        ),
      );
    });

    // Move the camera to the current location
    _mapController.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
  } else {
    // If current location has not been obtained, you can call a function to get the location
    await _getCurrentLocation();
  }
}

  void _removeLastMarker() {
    if (_markers.isNotEmpty) {
      setState(() {
        _markers.remove(_markers.last);
        _polylines.clear(); 
        _totalDistance = ''; 
      });
    }
  }
}