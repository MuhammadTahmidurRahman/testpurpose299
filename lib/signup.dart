import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart'; // Import this package
import 'createorjoinroom.dart';
import 'login.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _obscureTextPassword = true;
  bool _obscureTextConfirmPassword = true;
  File? _image;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isUploading = false;

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Request permissions for camera or gallery
  Future<void> _requestPermission(Permission permission) async {
    PermissionStatus status = await permission.request();
    if (status.isGranted) {
      print("Permission granted");
    } else {
      print("Permission denied");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Permission is required to use this feature")),
      );
    }
  }

  // Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      await _requestPermission(Permission.camera);
    } else if (source == ImageSource.gallery) {
      await _requestPermission(Permission.storage);
    }

    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 50,
    );
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  // Show the image picker dialog
  Future<void> _showImagePickerDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera),
              title: Text('Take a photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }

  // Upload image to Firebase Storage
  Future<String?> _uploadImageToFirebase(File? image) async {
    if (image == null) {
      print("No image selected");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select an image first.")));
      return null;
    }

    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference firebaseStorageRef =
    FirebaseStorage.instance.ref().child('uploads/$fileName');

    try {
      setState(() {
        _isUploading = true;
      });
      UploadTask uploadTask = firebaseStorageRef.putFile(image);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print('Upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100} %');
      });

      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print("Image uploaded. URL: $downloadUrl");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image uploaded successfully!")));
      return downloadUrl;
    } catch (e) {
      print("Upload failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image: ${e.toString()}")));
      return null;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _registerUser() async {
    // Validation checks...
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill up all the information box properly.")),
      );
      return;
    }

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must be at least 6 characters long")),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadImageToFirebase(_image!);
      }

      // Save user information to Realtime Database
      User? user = userCredential.user;
      if (user != null) {
        _database.child('users').child(user.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'photo': imageUrl ?? '', // Store the URL or leave it blank if no image
        });
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CreateOrJoinRoomPage()),
      );
    } catch (e) {
      print("Registration failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to register: ${e.toString()}")));
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please upload an image before signing up with Google")),
      );
      return;
    }

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        String? imageUrl = await _uploadImageToFirebase(_image!);

        // Save user information to Realtime Database
        User? user = userCredential.user;
        if (user != null) {
          _database.child('users').child(user.uid).set({
            'name': googleUser.displayName ?? 'N/A',
            'email': googleUser.email,
            'photo': imageUrl ?? '',
          });
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CreateOrJoinRoomPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No Google account found")),
        );
      }
    } catch (e) {
      print("Google Sign-In failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to sign in with Google: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hpbg1.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Create an Account',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Please fill in the information below to create an account.',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(height: 40),

                    // Name TextField
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 20),

                    // Email TextField
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 20),

                    // Password TextField
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureTextPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureTextPassword = !_obscureTextPassword;
                            });
                          },
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                      obscureText: _obscureTextPassword,
                    ),
                    SizedBox(height: 20),

                    // Confirm Password TextField
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureTextConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureTextConfirmPassword =
                              !_obscureTextConfirmPassword;
                            });
                          },
                        ),
                      ),
                      style: TextStyle(color: Colors.white),
                      obscureText: _obscureTextConfirmPassword,
                    ),
                    SizedBox(height: 20),

                    // Upload Image Button
                    GestureDetector(
                      onTap: _showImagePickerDialog,
                      child: Container(
                        width: double.infinity,
                        height: 60, // Same height as email and password fields
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3), // Same background color
                          borderRadius: BorderRadius.circular(10), // Rounded corners
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt, color: Colors.white), // Camera icon
                            SizedBox(width: 15), // Space between icon and text
                            Text(
                              _image == null ? 'Upload your photo here' : 'Photo selected',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),


                    ElevatedButton(
                      onPressed: _registerUser,
                      child: _isUploading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Sign Up', style: TextStyle(color: Colors.white)), // Text color set to white
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, // Button background color set to black
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.login, color: Colors.white), // Icon color set to white
                      label: Text("Sign Up with Google", style: TextStyle(color: Colors.white)), // Text color set to white
                      onPressed: _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, // Button background color set to black
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),


                    // Go to Login Page
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        );
                      },
                      child: Center(
                        child: Text(
                          'Already have an account? Login',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
