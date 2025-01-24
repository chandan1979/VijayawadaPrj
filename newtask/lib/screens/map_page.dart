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
  final TextEditingController _currentLocationController =
      TextEditingController();
  final TextEditingController _dropLocationController = TextEditingController();
  List<LatLng> _polylineCoordinates = [];
  List<String> _suggestions = [];
  List<String> categories = [];
  String? selectedCategory;
  bool _loading = true;
  final Set<Marker> markers = {};
  final String _googleApiKey =
      ""; // Replace with your API key.

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    // Check for permissions
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

    // Get current location
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _currentLocationController.text =
          "${position.latitude}, ${position.longitude}"; // Update text field
      _loading = false;
    });

    // Move the map to the current location
    _mapController.animateCamera(
      CameraUpdate.newLatLng(_currentLocation),
    );
  }

  Future<void> _fetchAddressSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions.clear();
      });
      return;
    }

    try {
      String apiUrl =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_googleApiKey";
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          setState(() {
            _suggestions = List<String>.from(
              data['predictions'].map((p) => p['description']),
            );
          });
        } else {
          throw Exception('Places API Error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to fetch suggestions');
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
    }
  }

  Future<void> _onSuggestionSelected(String suggestion) async {
    _dropLocationController.text = suggestion;
    _suggestions.clear();
    setState(() {}); // Clear the suggestions when one is selected
  }

  Future<void> _getPolyline(LatLng destination) async {
    try {
      // Initialize PolylinePoints
      PolylinePoints polylinePoints = PolylinePoints();

      // Fetch the polyline route using Google Directions API
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        _googleApiKey,
        PointLatLng(_currentLocation.latitude, _currentLocation.longitude),
        PointLatLng(destination.latitude, destination.longitude),
        travelMode: TravelMode.transit, // Change travel mode if needed
      );

      if (result.points.isNotEmpty) {
        setState(() {
          // Map points to LatLng and save to _polylineCoordinates
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

  Future<void> _onSearch() async {
    if (_dropLocationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a drop location.')),
      );
      return;
    }

    String address = _dropLocationController.text;

    try {
      // Replace with your API key
      String geocodingApiUrl =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$_googleApiKey';

      // Make the request
      final response = await http.get(Uri.parse(geocodingApiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          double lat = data['results'][0]['geometry']['location']['lat'];
          double lng = data['results'][0]['geometry']['location']['lng'];

          LatLng destination = LatLng(lat, lng);

          setState(() {
            _destinationLocation = destination;
          });

          await _getPolyline(destination);

          _mapController.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(
                  _currentLocation.latitude < destination.latitude
                      ? _currentLocation.latitude
                      : destination.latitude,
                  _currentLocation.longitude < destination.longitude
                      ? _currentLocation.longitude
                      : destination.longitude,
                ),
                northeast: LatLng(
                  _currentLocation.latitude > destination.latitude
                      ? _currentLocation.latitude
                      : destination.latitude,
                  _currentLocation.longitude > destination.longitude
                      ? _currentLocation.longitude
                      : destination.longitude,
                ),
              ),
              100.0,
            ),
          );
        } else {
          throw Exception('Geocoding failed: ${data['status']}');
        }
      } else {
        throw Exception('Failed to connect to Geocoding API');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5000/categories'));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          categories = data.cast<String>();
          if (categories.isNotEmpty) {
            selectedCategory = categories[0];
            fetchPlaces(selectedCategory!);
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
          await http.get(Uri.parse('http://127.0.0.1:5000/$category'));
      if (response.statusCode == 200) {
        List<dynamic> places = json.decode(response.body);
        setState(() {
          markers.clear();
          for (var place in places) {
            final LatLng position = LatLng(
              double.parse(place['latitude']),
              double.parse(place['longitude']),
            );

            markers.add(
              Marker(
                markerId: MarkerId(place['id'].toString()),
                position: position,
                infoWindow: InfoWindow(
                  title: place['places'],
                  snippet: 'Tap for more details',
                  onTap: () {
                    showPlaceDetails(context, {
                      'places': place['places'],
                      'description': place['description'],
                      'Entry_fee': place['Entry_fee'],
                      'Timings': place['Timings'],
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
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                place['places'],
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Description: ${place['description']}'),
              Text('Entry Fee: ${place['Entry_fee']}'),
              Text('Timings: ${place['Timings']}'),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    fetchCategories(); // Fetch categories when the screen is initialized
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps Route')),
      body: Column(
        children: [
          // Current Location Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _currentLocationController,
              readOnly: true, // Ensures the user cannot edit this field
              decoration: const InputDecoration(
                labelText: "Current Location",
                prefixIcon: Icon(Icons.my_location), // Adds an icon
              ),
            ),
          ),
          // Drop Location Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _dropLocationController,
              onChanged: _fetchAddressSuggestions,
              decoration: const InputDecoration(
                labelText: "Drop Location (e.g., Cubbon Park, Bangalore)",
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_suggestions[index]),
                    onTap: () => _onSuggestionSelected(_suggestions[index]),
                  );
                },
              ),
            ),
          ElevatedButton(
            onPressed: _onSearch,
            child: const Text('Show Route'),
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
                    markers: markers, // Displaying markers on the map
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