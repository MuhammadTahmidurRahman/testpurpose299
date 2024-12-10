import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'createorjoinroom.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:ui'; // For ImageFilter
import 'welcome.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? _profileImageUrl;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenForProfileChanges();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Real-time listener for user profile
  void _listenForProfileChanges() {
    if (user != null) {
      DatabaseReference userRef = _database.child('users/${user!.uid}');
      userRef.onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          setState(() {
            _profileImageUrl = data['photo'] ?? '';
            _nameController.text = data['name'] ?? '';
          });
        }
      });
    }
  }

  // Update name in 'users' and 'rooms'
  Future<void> _updateDisplayName(String newName) async {
    if (user != null) {
      String uid = user!.uid;

      // Update user's name in Firebase Auth
      await user!.updateDisplayName(newName);
      await user!.reload();
      FirebaseAuth.instance.currentUser;

      // Update name in the users node
      await _database.child('users/$uid').update({'name': newName});

      // Update the local state to reflect the new name instantly
      setState(() {
        _nameController.text = newName;
      });

      // Update name in all rooms where the user is a host or participant
      DatabaseReference roomsRef = _database.child('rooms');
      DataSnapshot roomsSnapshot = await roomsRef.get();

      if (roomsSnapshot.exists) {
        Map<dynamic, dynamic> roomsData = roomsSnapshot.value as Map<dynamic, dynamic>;

        for (var roomId in roomsData.keys) {
          final roomData = roomsData[roomId];

          // Update if user is the host
          if (roomData['hostId'] == uid) {
            await roomsRef.child(roomId).update({'hostName': newName});
          }

          // Update if user is a participant
          if (roomData['participants'] != null) {
            Map<dynamic, dynamic> participants = roomData['participants'];
            if (participants.containsKey(uid)) {
              await roomsRef.child(roomId).child('participants').child(uid).update({'name': newName});
            }
          }
        }
      }
    }
  }

  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Name'),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(hintText: "Enter your new name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  await _updateDisplayName(_nameController.text);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      if (user != null) {
        String uid = user!.uid;

        // Remove user data from all rooms (participants)
        await _deleteUserDataFromRooms(uid);

        // Delete profile image from Firebase Storage
        if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(_profileImageUrl!).delete();
        }


        // Delete user data from Firebase Realtime Database
        await _database.child('users/$uid').remove();

        // Delete user's hosted rooms
        DatabaseReference roomsRef = _database.child('rooms');
        DataSnapshot snapshot = await roomsRef.get();
        if (snapshot.exists) {
          Map<dynamic, dynamic> roomsData = snapshot.value as Map<dynamic, dynamic>;
          for (var roomId in roomsData.keys) {
            final room = roomsData[roomId];
            if (room['hostId'] == uid) {
              await roomsRef.child(roomId).remove();
            }
          }
        }

        // Delete user account from Firebase Auth
        await user!.delete();
        // Sign out from Google
        await _googleSignIn.signOut();

        // Navigate back to the Welcome page and remove all previous pages from the stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => WelcomePage()),
              (Route<dynamic> route) => false, // This removes all routes from the stack
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: ${e.toString()}')),
      );
    }
  }
  Future<void> _deleteUserDataFromRooms(String uid) async {
    try {
      // Get a reference to the rooms node in Firebase Realtime Database
      DatabaseReference roomsRef = _database.child('rooms');

      // Fetch all rooms data
      DataSnapshot roomsSnapshot = await roomsRef.get();
      if (roomsSnapshot.exists) {
        Map<dynamic, dynamic> roomsData = roomsSnapshot.value as Map<dynamic, dynamic>;

        // Iterate over each room to check if the user is a participant
        for (var roomId in roomsData.keys) {
          final roomData = roomsData[roomId];

          // If the user is the host, skip removing them as they are already handled elsewhere
          if (roomData['hostId'] == uid) continue;

          // Check and remove the user from the 'participants' node
          if (roomData['participants'] != null) {
            Map<dynamic, dynamic> participants = roomData['participants'];
            if (participants.containsKey(uid)) {
              // Remove the user from the participants list
              await roomsRef.child(roomId).child('participants').child(uid).remove();
            }
          }
        }
      }
    } catch (e) {
      print('Error while deleting user data from rooms: ${e.toString()}');
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Text('Are you sure you want to delete your account? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAccount();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    // Sign out from Google
    await _googleSignIn.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => WelcomePage()),
          (Route<dynamic> route) => false, // This removes all routes from the stack
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/hpbg1.png', fit: BoxFit.cover),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: kToolbarHeight,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Profile',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => CreateOrJoinRoomPage()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? NetworkImage(_profileImageUrl!)
                        : null,
                  ),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                              ),
                              child: Column(
                                children: [
                                  Center(
                                    child: Text(
                                      user?.displayName ?? _nameController.text,
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Center(
                                    child: Text(
                                      user?.email ?? 'No Email',
                                      style: TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  GestureDetector(
                                    onTap: _showEditNameDialog,
                                    child: ListTile(
                                      leading: Icon(Icons.edit, color: Colors.white),
                                      title: Text('Edit Profile', style: TextStyle(color: Colors.white)),
                                      tileColor: Colors.white.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                  Divider(color: Colors.grey),
                                  GestureDetector(
                                    onTap: _showDeleteAccountDialog,
                                    child: ListTile(
                                      leading: Icon(Icons.delete_forever, color: Colors.white),
                                      title: Text('Delete Account', style: TextStyle(color: Colors.white)),
                                      tileColor: Colors.white.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Spacer(),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                          onPressed: () async {
                            await logout(context); // Call the centralized logout function
                          },
                          child: Text('Logout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
