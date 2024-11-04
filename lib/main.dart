import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';  // Import Firebase core
import 'package:firebase_auth/firebase_auth.dart';  // Import Firebase Auth
import 'splash.dart';  // Import the Splash page
import 'login.dart';  // Import the Login page
import 'createorjoinroom.dart';  // Import the Create or Join Room page

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();  // Initialize Firebase

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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