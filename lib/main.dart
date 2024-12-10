import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Database
import 'splash.dart';
import 'login.dart';
import 'createorjoinroom.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase and store it in `app`
  final FirebaseApp app = await Firebase.initializeApp();

  // Create a Firebase Database reference using the initialized app
  final FirebaseDatabase database = FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: "https://pictora-7f0ad-default-rtdb.asia-southeast1.firebasedatabase.app"
  );

  runApp(MyApp(database: database)); // Pass the database reference to your app
}

class MyApp extends StatelessWidget {
  final FirebaseDatabase database; // Use FirebaseDatabase type

  MyApp({required this.database}); // Require the database reference in the constructor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pictora',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            // Check if user is logged in
            if (snapshot.hasData) {
              return CreateOrJoinRoomPage(); // User is logged in
            } else {
              return SplashScreen(); // User is not logged in
            }
          }
          return Center(child: CircularProgressIndicator()); // Show loading indicator while checking auth state
        },
      ),
    );
  }
}
