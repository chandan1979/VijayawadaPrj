// import 'dart:convert';  // For decoding JSON
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class MapsScreen extends StatefulWidget {
//   @override
//   _MapsScreenState createState() => _MapsScreenState();
// }

// class _MapsScreenState extends State<MapsScreen> {
//   // List to hold the categories data
//   List<String> categories = [];

//   // Function to fetch data from the API
//   Future<void> fetchCategories() async {
//     final response = await http.get(Uri.parse('http://20.174.25.143:8000/categories'));

//     if (response.statusCode == 200) {
//       // If the server returns a 200 OK response, parse the JSON
//       List<dynamic> data = json.decode(response.body);
//       setState(() {
//         categories = data.cast<String>();  // Cast data to a List of Strings
//       });
//     } else {
//       // If the server returns an error, throw an exception
//       throw Exception('Failed to load categories');
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     fetchCategories();  // Call the function to fetch data
    
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Categories'),
//       ),
//       body: categories.isEmpty
//           ? Center(child: CircularProgressIndicator())  // Loading indicator while data is being fetched
//           : ListView.builder(
//               itemCount: categories.length,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text(categories[index]),
//                 );
//               },
//             ),
//     );
//   }
// }
