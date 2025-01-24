import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  LatLng _currentLocation = const LatLng(0.0, 0.0);
  LatLng? _destinationLocation;
  List<LatLng> _polylineCoordinates = [];
  List<String> _categories = [];
  List<String> _suggestions = [];
  List<Marker> _markers = [];
  String selectedCategory = "";
  bool _loading = true;

  final String _googleApiKey =
      ""; // Replace with your API key.

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions are permanently denied.')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _loading = false;
    });

    _mapController.animateCamera(
      CameraUpdate.newLatLng(_currentLocation),
    );
  }

  Future<void> fetchCategories() async {
    try {
      final response =
          await http.get(Uri.parse('http://10.0.2.2:5000/categories'));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _categories = data.cast<String>();
          if (_categories.isNotEmpty) {
            selectedCategory = _categories[0];
            fetchPlaces(selectedCategory);
            print("fetchCategoriesandplaces");
          }
        });
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> fetchPlaces(String category) async {
    try {
      final response =
          await http.get(Uri.parse('http://10.0.2.2:5000/$category'));
      if (response.statusCode == 200) {
        List<dynamic> places = json.decode(response.body);
        print("Places fetched: $places"); // Log the list of places to inspect
        setState(() {
          _markers.clear();
          for (var place in places) {
            final LatLng position = LatLng(
              double.parse(place['latitude']?.toString() ??
                  '0.0'), // Handle missing latitude
              double.parse(place['longitude']?.toString() ??
                  '0.0'), // Handle missing longitude
            );
            print("Adding");
            _markers.add(
              Marker(
                markerId: MarkerId(place['id'].toString()),
                position: position,
                infoWindow: InfoWindow(
                  title: place['places'],
                  snippet: 'Tap for more details',
                  onTap: () {
                    // Pass the latitude and longitude along with other details
                    showPlaceDetails(context, {
                      'places': place['places'] ??
                          'No Name', // Fallback if places is null
                      'description':
                          place['description'] ?? 'No description available',
                      'Entry_fee': place['Entry_fee']?.toString() ??
                          'N/A', // Ensure Entry_fee is a string
                      'Timings': place['Timings'] ?? 'No timings provided',
                      'latitude': place['latitude'] ?? 0.0, // Add latitude here
                      'longitude':
                          place['longitude'] ?? 0.0, // Add longitude here
                    });
                  },
                ),
              ),
            );
          }
        });
      } else {
        print('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching places: $e');
    }
  }

  void showPlaceDetails(BuildContext context, Map<String, dynamic> place) {
    // Ensure latitude and longitude are converted to double if they're integers
    double lat = (place['latitude'] ?? 0.0).toDouble();
    double lng = (place['longitude'] ?? 0.0).toDouble();

    // Show details including lat/lng
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(place['places']),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description: ${place['description']}'),
              Text('Timings: ${place['Timings']}'),
              Text('Entry Fee: ${place['Entry_fee']}'),
              Text('Latitude: $lat'),
              Text('Longitude: $lng'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Close the dialog
                Navigator.of(context).pop();
                // Trigger route calculation
                _getRouteToPlace(place); // Pass the correct place data
              },
              child: Text('Show Route'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getRouteToPlace(Map<String, dynamic> place) async {
    try {
      // Safely extract and convert latitude and longitude to double
      double lat = (place['latitude'] ?? 0).toDouble();
      double lng = (place['longitude'] ?? 0).toDouble();

      // Check if lat and lng are valid
      if (lat == 0.0 || lng == 0.0) {
        throw Exception('Invalid coordinates for ${place['places']}');
      }

      LatLng destination = LatLng(lat, lng);

      // Call the polyline function
      await _getPolyline(destination);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching route: $e')),
      );
    }
  }

  Future<void> _getPolyline(LatLng destination) async {
    try {
      PolylinePoints polylinePoints = PolylinePoints();

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        _googleApiKey,
        PointLatLng(_currentLocation.latitude, _currentLocation.longitude),
        PointLatLng(destination.latitude, destination.longitude),
        travelMode: TravelMode.transit,
      );

      if (result.points.isNotEmpty) {
        setState(() {
          _polylineCoordinates = result.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        });
      } else {
        throw Exception('No route found.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching route: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps Route')),
      body: Column(
        children: [
          // Category Dropdown
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: selectedCategory,
              onChanged: (newCategory) {
                setState(() {
                  selectedCategory = newCategory!;
                  fetchPlaces(selectedCategory);
                });
              },
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    onMapCreated: (controller) => _mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation,
                      zoom: 15.0,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    polylines: {
                      if (_polylineCoordinates.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('route'),
                          color: Colors.blue,
                          width: 5,
                          points: _polylineCoordinates,
                        ),
                    },
                    markers: Set<Marker>.from(_markers),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
