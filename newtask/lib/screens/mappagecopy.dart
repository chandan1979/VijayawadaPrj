// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// class MapScreen extends StatelessWidget {
//   // Define static LatLng positions for markers
//   static const LatLng _pGooglePlex = LatLng(13.0486755, 80.2274267);
//   static const LatLng _pApplepark = LatLng(13.0581208, 80.233565);
//   static const LatLng _pMarinabeach = LatLng(13.049894, 80.282730);
//   static const LatLng _pBesantnagarbeach = LatLng(13.0009322, 80.2651229);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Google Map with Markers'),
//       ),
//       body: GoogleMap(
//         initialCameraPosition: const CameraPosition(
//           target: _pGooglePlex,
//           zoom: 13,
//         ),
//         markers: {
//           Marker(
//             markerId: const MarkerId("_currentLocation"),
//             position: _pGooglePlex,
//             icon: BitmapDescriptor.defaultMarker,
//             infoWindow: const InfoWindow(title: "GooglePlex"),
//           ),
//           Marker(
//             markerId: const MarkerId("_sourceLocation"),
//             position: _pApplepark,
//             icon: BitmapDescriptor.defaultMarker,
//             infoWindow: const InfoWindow(title: "Apple Park"),
//           ),
//           Marker(
//             markerId: const MarkerId("_Location3"),
//             position: _pMarinabeach,
//             icon: BitmapDescriptor.defaultMarker,
//             infoWindow: const InfoWindow(title: "Marina Beach"),
//           ),
//           Marker(
//             markerId: const MarkerId("_Location4"),
//             position: _pBesantnagarbeach,
//             icon: BitmapDescriptor.defaultMarker,
//             infoWindow: const InfoWindow(title: "Besant Nagar Beach"),
//           ),
//         },
//       ),
//     );
//   }
// }


// import 'dart:convert'; // For decoding JSON
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;

// class MapsScreen extends StatefulWidget {
//   @override
//   _MapsScreenState createState() => _MapsScreenState();
// }

// class _MapsScreenState extends State<MapsScreen> {
//   List<String> categories = []; // List to hold categories
//   String? selectedCategory; // Current selected category
//   Set<Marker> markers = {}; // Markers to display on the map
//   late GoogleMapController mapController;

//   @override
//   void initState() {
//     super.initState();
//     fetchCategories(); // Load categories and default places on init
//   }

//   Future<void> fetchCategories() async {
//     try {
//       final response =
//           await http.get(Uri.parse('http://20.174.25.143:8000/categories'));
//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);
//         setState(() {
//           categories = data.cast<String>();
//           if (categories.isNotEmpty) {
//             selectedCategory = categories[0]; // Set default category
//             fetchPlaces(selectedCategory!); // Fetch places for default category
//           }
//         });
//       } else {
//         throw Exception('Failed to load categories');
//       }
//     } catch (e) {
//       print('Error fetching categories: $e');
//     }
//   }

//   Future<void> fetchPlaces(String category) async {
//     try {
//       final response =
//           await http.get(Uri.parse('http://20.174.25.143:8000/$category'));
//       if (response.statusCode == 200) {
//         List<dynamic> places = json.decode(response.body);
//         setState(() {
//           markers.clear(); // Clear existing markers before adding new ones

//           for (var place in places) {
//             String placeId = place['id'].toString();
//             String description = place['description'].toString();
//             String entryFee = place['Entry_fee'].toString();
//             String timings = place['Timings'].toString();
//             String busFromKoyambedu =
//                 place['Bus_from_koyambedu_bus_stand_direct_connecting_bus']
//                     .toString();
//             String switchingBus = place['Switching_bus'].toString();
//             final LatLng _initialPosition = LatLng(
//               double.parse(place['latitude']),
//               double.parse(place['longitude']),
//             );

//             markers.add(
//               Marker(
//                 markerId: MarkerId(placeId),
//                 position: _initialPosition,
//                 infoWindow: InfoWindow(
//                   title: place['places'],
//                   snippet: 'Tap for more details',
//                   onTap: () {
//                     // Show detailed view in a Bottom Sheet
//                     showPlaceDetails(context, {
//                       'places': place['places'],
//                       'description': description,
//                       'Entry_fee': entryFee,
//                       'Timings': timings,
//                       'Bus_from_koyambedu_bus_stand_direct_connecting_bus': busFromKoyambedu,
//                       'Switching_bus': switchingBus,
//                     });
//                   },
//                 ),
//               ),
//             );
//           }
//         });
//       } else {
//         print(
//             'Failed to load places: ${response.statusCode}'); // Log error status
//       }
//     } catch (e) {
//       print('Error fetching places: $e'); // Log any exceptions
//     }
//   }

//   void showPlaceDetails(BuildContext context, Map<String, dynamic> place) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext context) {
//         return Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   place['places'],
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 10),
//                 Text('Description: ${place['description']}'),
//                 Text('Entry Fee: ${place['Entry_fee']}'),
//                 Text('Timings: ${place['Timings']}'),
//                 Text('Direct Bus: ${place['Bus_from_koyambedu_bus_stand_direct_connecting_bus']}'),
//                 Text('Switching Bus: ${place['Switching_bus']}'),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Map View with Categories'),
//       ),
//       body: Stack(
//         children: [
//           GoogleMap(
//             onMapCreated: (controller) => mapController = controller,
//             markers: markers,
//             initialCameraPosition: CameraPosition(
//               target: LatLng(13.0827, 80.2707), // Default location (Chennai)
//               zoom: 12.0,
//             ),
//           ),
//           Positioned(
//             top: 20,
//             left: 10,
//             right: 10,
//             child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(8),
//                 boxShadow: [
//                   BoxShadow(color: Colors.black26, blurRadius: 4),
//                 ],
//               ),
//               child: DropdownButton<String>(
//                 value: selectedCategory,
//                 isExpanded: true,
//                 icon: Icon(Icons.arrow_drop_down),
//                 underline: SizedBox(),
//                 onChanged: (newValue) {
//                   setState(() {
//                     selectedCategory = newValue!;
//                   });
//                   print(
//                       'Selected category changed to $selectedCategory'); // Debugging line
//                   fetchPlaces(
//                       selectedCategory!); // Load places for the selected category
//                 },
//                 items: categories.map((category) {
//                   return DropdownMenuItem(
//                     value: category,
//                     child: Text(category),
//                   );
//                 }).toList(),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// androidmanifest.xml
//  <manifest xmlns:android="http://schemas.android.com/apk/res/android">
//     <application
//         android:label="demo"
//         android:name="${applicationName}"
//         android:icon="@mipmap/ic_launcher">
//         <meta-data android:name="com.google.android.geo.API_KEY"
//                android:value="AIzaSyDVXx7AiLZgDg9mjPEa5wkjtPeYUYETmF4"/>
//         <activity
//             android:name=".MainActivity"
//             android:exported="true"
//             android:launchMode="singleTop"
//             android:taskAffinity=""
//             android:theme="@style/LaunchTheme"
//             android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
//             android:hardwareAccelerated="true"
//             android:windowSoftInputMode="adjustResize">
//             <!-- Specifies an Android theme to apply to this Activity as soon as
//                  the Android process has started. This theme is visible to the user
//                  while the Flutter UI initializes. After that, this theme continues
//                  to determine the Window background behind the Flutter UI. -->
//             <meta-data
//               android:name="io.flutter.embedding.android.NormalTheme"
//               android:resource="@style/NormalTheme"
//               />
//             <intent-filter>
//                 <action android:name="android.intent.action.MAIN"/>
//                 <category android:name="android.intent.category.LAUNCHER"/>
//             </intent-filter>
//         </activity>
//         <!-- Don't delete the meta-data below.
//              This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
//         <meta-data
//             android:name="flutterEmbedding"
//             android:value="2" />
//         <meta-data android:name="com.google.android.geo.API_KEY"
//             android:value="AIzaSyDVXx7AiLZgDg9mjPEa5wkjtPeYUYETmF4"/>
//     </application>
//     <!-- Required to query activities that can process text, see:
//          https://developer.android.com/training/package-visibility and
//          https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.
//          In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
//     <queries>
//         <intent>
//             <action android:name="android.intent.action.PROCESS_TEXT"/>
//             <data android:mimeType="text/plain"/>
//         </intent>
//     </queries>
// </manifest>