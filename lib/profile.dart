import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'login.dart';

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
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    if (user != null) {
      DatabaseReference userRef = _database.child('users').child(user!.uid);
      DataSnapshot snapshot = await userRef.get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> userData = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _profileImageUrl = userData['photo'] ?? '';
          _nameController.text = userData['name'] ?? '';
        });
      }
    }
  }

  Future<void> _updateDisplayName(String newName) async {
    if (user != null) {
      await user!.updateDisplayName(newName);
      await user!.reload();
      setState(() {
        FirebaseAuth.instance.currentUser;
      });

      await _database.child('users').child(user!.uid).update({
        'name': newName,
      });
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

  // Show a confirmation dialog before account deletion
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
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAccount();
              },
              child: Text('Delete'),
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

        // Delete user profile image from Firebase Storage if it exists
        if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(_profileImageUrl!).delete();
        }

        // Delete user data from Realtime Database
        await _database.child('users').child(uid).remove();

        // Reference to the Firebase Storage
        final storageRef = FirebaseStorage.instance.ref();

        // Delete user's hosted rooms from the 'rooms' node and images within each room
        final roomsRef = _database.child('rooms');
        final snapshot = await roomsRef.get();

        if (snapshot.exists) {
          Map<dynamic, dynamic> roomsData = snapshot.value as Map<dynamic, dynamic>;

          // Loop through each room and delete associated images and room data
          for (var roomId in roomsData.keys) {
            final room = roomsData[roomId];
            if (room['hostId'] == uid) {

              // Delete images in Firebase Storage for this room
              final roomImagesRef = storageRef.child('rooms/$roomId');
              final ListResult images = await roomImagesRef.listAll();

              for (var item in images.items) {
                await item.delete();  // Delete each image
              }

              // Delete room details in Realtime Database
              await roomsRef.child(roomId).remove();
            }
          }
        }

        // Delete user from Firebase Authentication
        await user!.delete();

        // Navigate to the login page after successful account deletion
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: ${e.toString()}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? NetworkImage(_profileImageUrl!)
                    : null,
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                user?.displayName ?? _nameController.text,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                user?.email ?? 'No Email',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            SizedBox(height: 40),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit Profile'),
              onTap: _showEditNameDialog,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever),
              title: Text('Delete Account'),
              onTap: _showDeleteAccountDialog,
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                child: Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
