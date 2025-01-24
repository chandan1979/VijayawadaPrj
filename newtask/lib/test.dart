import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

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
  GoogleMapController? _mapController; // Changed to nullable
  LatLng _currentLocation = const LatLng(0.0, 0.0);
  LatLng? _destinationLocation;
  List<LatLng> _polylineCoordinates = [];
  List<String> _categories = [];
  List<String> _suggestions = [];
  Set<Marker> _markers = {}; // Changed to Set
  String? selectedCategory; // Changed to nullable
  bool _loading = true;

  // Add the categoryLogos map here
  final Map<String, String> categoryLogos = {
    "Attraction": "assets/images/Attraction.png",
    "Beaches": "assets/images/Beaches.png",
    "Stadium": "assets/images/Stadium.png",
    "Temple": "assets/images/Temple.png",
    "Harbour": "assets/images/Harbour.png",
    "Go-karting": "assets/images/Go-karting.png",
    "Shopping streets": "assets/images/Shopping streets.png",
    "Memorials": "assets/images/Memorials.png",
    "Parks": "assets/images/Parks.png",
    "Amusement park": "assets/images/Amusement park.png",
    "Gaming": "assets/images/Gaming.png",
    "Malls": "assets/images/Malls.png",
    "Famous places": "assets/images/Famous places.png",
    "Cinemas": "assets/images/Cinemas.png",
    "Boating": "assets/images/Boating.png",
    "Cultural center": "assets/images/Cultural center.png",
    "Church": "assets/images/Church.png",
    "Lake": "assets/images/Lake.png",
    "Museum": "assets/images/Museum.png",
    "Mosque": "assets/images/Mosque.png",
    "Zoo": "assets/images/Zoo.png",
    "Library": "assets/images/Library.png",
    "Food street": "assets/images/Food street.png",
    "War memorial": "assets/images/War memorial.png",
    "Hotels": "assets/images/Hotels.png",
  };

  final Map<String, String> travelModeLogos = {
    "Driving": "assets/images/Driving.png",
    "Two-Wheeler": "assets/images/Two-Wheeler.png",
    "Cycling": "assets/images/Cycling.png",
    "Walking": "assets/images/Walking.png",
  };
  final String _googleApiKey = "AIzaSyAXWDIjZD5014ibmxgiIxBDq-CNrs3Z56c";

  Future<BitmapDescriptor> getCustomMarkerIcon(String category) async {
    String assetPath = categoryLogos[category] ?? 'assets/images/default.png';
    return BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(5, 5)), // Adjust the size
      assetPath,
    );
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    // Load the asset data
    ByteData? data = await rootBundle.load(path);

    if (data == null) {
      throw Exception('Failed to load asset: $path');
    }

    // Instantiate the image codec and get the frame
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();

    // Convert the image to ByteData and return as Uint8List
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
            ?.buffer
            .asUint8List() ??
        Uint8List(0);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // Check and request location permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // Get the current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);

        // Add a marker for the current location
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: _currentLocation,
            infoWindow: const InfoWindow(
              title: 'Current Location',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed), // Red marker
          ),
        );

        _loading = false;
      });

      // Move the camera to the current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 15.0),
      );
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
            fetchPlaces(selectedCategory!);
          }
        });
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching categories: $e')),
      );
    }
  }

  Future<void> fetchPlaces(String category) async {
    try {
      final response =
          await http.get(Uri.parse('http://10.0.2.2:5000/$category'));
      if (response.statusCode == 200) {
        List<dynamic> places = json.decode(response.body);
        Set<Marker> newMarkers = {};

        // Load the custom marker icon for the selected category
        String assetPath =
            categoryLogos[category] ?? 'assets/images/default.png';

        // Adjust the size (100 is the width here, you can change this to your desired width)
        final Uint8List markerIcon = await getBytesFromAsset(assetPath, 100);

        // Create the custom marker with the resized image
        BitmapDescriptor customIcon = BitmapDescriptor.fromBytes(markerIcon);

        for (var place in places) {
          final double lat =
              double.tryParse(place['latitude']?.toString() ?? '') ?? 0.0;
          final double lng =
              double.tryParse(place['longitude']?.toString() ?? '') ?? 0.0;

          if (lat != 0.0 && lng != 0.0) {
            final marker = Marker(
              markerId: MarkerId(
                  place['id']?.toString() ?? DateTime.now().toString()),
              position: LatLng(lat, lng),
              icon: customIcon, // Use the resized custom icon
              infoWindow: InfoWindow(
                title: place['places'] ?? 'Unknown',
                snippet: 'Tap for more details',
                onTap: () => showPlaceDetails(context, place),
              ),
            );
            newMarkers.add(marker);
          }
        }

        // Update the map with new markers
        setState(() {
          _markers = newMarkers;
        });
      } else {
        throw Exception('Failed to load places: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching places: $e')),
      );
    }
  }

  void showPlaceDetails(BuildContext context, Map<String, dynamic> place) {
    // Convert latitude and longitude to double
    double lat = double.tryParse(place['latitude']?.toString() ?? '0.0') ?? 0.0;
    double lng =
        double.tryParse(place['longitude']?.toString() ?? '0.0') ?? 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(place['places']?.toString() ?? 'Unknown Place'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Description: ${place['discription']}'),
                Text('Timings: ${place['timings']}'),
                Text('Entry Fee: ${place['entryfee']}'),
                Text('Latitude: $lat'),
                Text('Longitude: $lng'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _destinationLocation =
                      LatLng(lat, lng); // Update _destinationLocation
                });
                _getRouteToPlace(place); // Call the route function
              },
              child: const Text('Show Route'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getRouteToPlace(Map<String, dynamic> place) async {
    try {
      double lat =
          double.tryParse(place['latitude']?.toString() ?? '0.0') ?? 0.0;
      double lng =
          double.tryParse(place['longitude']?.toString() ?? '0.0') ?? 0.0;

      if (lat == 0.0 || lng == 0.0) {
        throw Exception('Invalid coordinates for ${place['places']}');
      }

      LatLng destination = LatLng(lat, lng);
      await _getPolyline(destination);

      // Adjust map bounds to show both markers and the route
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentLocation.latitude < lat ? _currentLocation.latitude : lat,
          _currentLocation.longitude < lng ? _currentLocation.longitude : lng,
        ),
        northeast: LatLng(
          _currentLocation.latitude > lat ? _currentLocation.latitude : lat,
          _currentLocation.longitude > lng ? _currentLocation.longitude : lng,
        ),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50), // 50 is padding
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting route: $e')),
      );
    }
  }

  // Add this list for travel modes
  final List<Map<String, dynamic>> travelModes = [
    {'label': 'Driving', 'mode': TravelMode.transit},
    {'label': 'Walking', 'mode': TravelMode.walking},
    {'label': 'Cycling', 'mode': TravelMode.bicycling},
    {
      'label': 'Two-Wheeler',
      'mode': TravelMode.driving
    }, // No separate mode for two-wheeler, use driving
  ];

  TravelMode _selectedTravelMode = TravelMode.driving;

  Future<void> _getPolyline(LatLng destination) async {
    try {
      PolylinePoints polylinePoints = PolylinePoints();
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        _googleApiKey,
        PointLatLng(_currentLocation.latitude, _currentLocation.longitude),
        PointLatLng(destination.latitude, destination.longitude),
        travelMode: _selectedTravelMode,
      );

      if (result.points.isNotEmpty) {
        setState(() {
          _polylineCoordinates = result.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        });
      } else {
        throw Exception('No route found');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching route: $e')),
      );
    }
  }

// Add this to the build method above the Google Map widget
  Widget _buildTravelModeDropdown() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: Alignment.center, // Center the dropdown
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16.0), // Add padding inside the container
          decoration: BoxDecoration(
            color: Colors.white, // Set background color to white
            borderRadius: BorderRadius.circular(20), // Round the corners
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.5), blurRadius: 5)
            ], // Optional shadow
          ),
          child: DropdownButton<TravelMode>(
            value: _selectedTravelMode,
            onChanged: (TravelMode? newMode) {
              if (newMode != null) {
                setState(() {
                  _selectedTravelMode = newMode;
                  _polylineCoordinates.clear(); // Clear the existing polylines
                });
              }
            },
            isExpanded: true, // Make the dropdown full width
            underline: Container(), // Remove the default underline
            items: travelModes.map((mode) {
              return DropdownMenuItem<TravelMode>(
                value: mode['mode'],
                child: Row(
                  children: [
                    Image.asset(
                      travelModeLogos[mode['label']] ??
                          '', // Add the icon for the mode
                      width: 25,
                      height: 25,
                    ),
                    const SizedBox(width: 10),
                    Text(mode['label']), // Display the label
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
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
      appBar: AppBar(title: const Text('Chennai Tourist Attractions')),
      body: Stack(
        children: [
          Column(
            children: [
              // Other UI components can stay here like the logo and zoom controls
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        onMapCreated: (controller) {
                          setState(() {
                            _mapController = controller;
                          });
                        },
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation,
                          zoom: 15.0,
                        ),
                        myLocationEnabled: false,
                        zoomControlsEnabled: false,
                        markers: _markers,
                        polylines: {
                          if (_polylineCoordinates.isNotEmpty)
                            Polyline(
                              polylineId: const PolylineId('route'),
                              color: Colors.blue,
                              width: 5,
                              points: _polylineCoordinates,
                            ),
                        },
                      ),
              ),
            ],
          ),

          // Floating dropdown for category selection
          Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.center, // Center the dropdown
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0), // Add some padding
                    decoration: BoxDecoration(
                      color: Colors.white, // Set background color to white
                      borderRadius:
                          BorderRadius.circular(20), // Rounded corners
                    ),
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      hint: const Text('Select a category'),
                      onChanged: (newCategory) {
                        if (newCategory != null) {
                          setState(() {
                            _polylineCoordinates
                                .clear(); // Clear the existing polylines
                            selectedCategory = newCategory;
                            fetchPlaces(newCategory);
                          });
                        }
                      },
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Row(
                            children: [
                              Image.asset(
                                categoryLogos[category] ?? '',
                                width: 25,
                                height: 25,
                              ),
                              const SizedBox(width: 10),
                              Text(category),
                            ],
                          ),
                        );
                      }).toList(),
                      isExpanded:
                          true, // Make the dropdown full width inside the container
                      // style: TextStyle(fontSize: 16), // Reduce the font size
                    ),
                  ),
                ),
              )),

          // Floating dropdown for travel mode
          // Floating dropdown for category selection
          Positioned(
              top: 70,
              left: 10,
              right: 10,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.center, // Center the dropdown
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0), // Add some padding
                    decoration: BoxDecoration(
                      color: Colors.white, // Set background color to white
                      borderRadius:
                          BorderRadius.circular(20), // Rounded corners
                    ),
                    child: DropdownButton<TravelMode>(
                      value: _selectedTravelMode,
                      onChanged: (TravelMode? newMode) {
                        if (newMode != null) {
                          setState(() {
                            _selectedTravelMode = newMode;
                            _polylineCoordinates
                                .clear(); // Clear the existing polylines
                          });
                        }
                      },
                      isExpanded: true, // Make the dropdown full width
                      underline: Container(), // Remove the default underline
                      items: travelModes.map((mode) {
                        return DropdownMenuItem<TravelMode>(
                          value: mode['mode'],
                          child: Row(
                            children: [
                              Image.asset(
                                travelModeLogos[mode['label']] ??
                                    '', // Add the icon for the mode
                                width: 25,
                                height: 25,
                              ),
                              const SizedBox(width: 10),
                              Text(mode['label']), // Display the label
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              )),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.asset(
                'assets/images/companylogo.png',
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  mini: true,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  mini: true,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
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
