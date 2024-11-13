import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'createorjoinroom.dart';
import 'arrangedphoto.dart';

class EventRoom extends StatelessWidget {
  final String eventCode;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  EventRoom({required this.eventCode});

  // Delete room function
  Future<void> _deleteRoom(BuildContext context) async {
    await _databaseRef.child("rooms/$eventCode").remove();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Room has been permanently deleted.')),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Room', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete this room? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('No', style: TextStyle(color: Colors.blue)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteRoom(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => CreateOrJoinRoomPage()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPhoto(BuildContext context, String userId, String username) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null) {
      final user = FirebaseAuth.instance.currentUser;
      final roomSnapshot = await _databaseRef.child("rooms/$eventCode").get();

      if (!roomSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room not found.')),
        );
        return;
      }

      final roomData = roomSnapshot.value as Map<dynamic, dynamic>? ?? {};

      // Debugging: Log fetched room data
      print('Fetched room data: $roomData');

      bool isHost = false;
      String folderType = '';
      String userDataPath = '';
      String displayName = '';

      // Check if the current user is the host using composite key
      if (roomData.containsKey('host')) {
        for (var key in (roomData['host'] as Map<dynamic, dynamic>).keys) {
          final hostData = roomData['host'][key];
          if (hostData['hostId'] == userId) {
            isHost = true;
            folderType = "host";
            userDataPath = 'rooms/$eventCode/host/$key';
            displayName = hostData['hostName'] ?? 'Unknown Host';
            break;
          }
        }
      }

      // Check if the user is a guest using composite key
      if (!isHost && roomData.containsKey('guests')) {
        for (var key in (roomData['guests'] as Map<dynamic, dynamic>).keys) {
          final guestData = roomData['guests'][key];
          if (guestData['guestId'] == userId) {
            folderType = "guests";
            userDataPath = 'rooms/$eventCode/guests/$key';
            displayName = guestData['guestName'] ?? 'Unknown Guest';
            break;
          }
        }
      }

      // Check if userId was found as either host or guest
      if (folderType.isEmpty || userDataPath.isEmpty || displayName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not found in room.')),
        );
        return;
      }

      // Debugging logs
      print('Resolved folderType: $folderType');
      print('Resolved userDataPath: $userDataPath');

      // Upload photos to Firebase Storage
      String storageFolderPath = 'rooms/$eventCode/$folderType/$displayName/$userId/photos/';
      for (var file in pickedFiles) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        File convertedFile = File(file.path);
        String storagePath = '$storageFolderPath$fileName';

        await _storage.ref(storagePath).putFile(convertedFile);
      }

      // Update the `uploadedPhotoFolderPath` key for the matched user
      await _databaseRef.child(userDataPath).update({
        'uploadedPhotoFolderPath': storageFolderPath,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pickedFiles.length} photos uploaded successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No photos selected.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String currentUserId = user?.uid ?? '';
    final String username = user?.displayName ?? 'Guest';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/hpbg1.png', fit: BoxFit.cover),
          FutureBuilder<DataSnapshot>(
            future: _databaseRef.child("rooms/$eventCode").get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Error loading room data"));

              final roomData = snapshot.data!.value as Map<dynamic, dynamic>? ?? {};
              final roomName = roomData['roomName'] ?? 'No Room Name';

              final hostMap = roomData['host'] as Map<dynamic, dynamic>? ?? {};
              String hostName = 'Unknown Host';
              String? hostPhotoUrl;
              bool isHost = false;

              if (hostMap.isNotEmpty) {
                for (var entry in hostMap.entries) {
                  final host = entry.value as Map<dynamic, dynamic>;
                  hostName = host['hostName'] ?? 'Unknown Host';
                  hostPhotoUrl = host['hostPhotoUrl'];
                  if (host['hostId'] == currentUserId) {
                    isHost = true;
                  }
                  break;
                }
              }

              final guestsData = roomData['guests'] as Map<dynamic, dynamic>? ?? {};
              List<Map<String, dynamic>> guestList = [];
              guestsData.forEach((key, value) {
                final guest = value as Map<dynamic, dynamic>;
                guestList.add({
                  'guestName': guest['guestName'] ?? 'Unknown Guest',
                  'guestPhotoUrl': guest['guestPhotoUrl'],
                });
              });

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => CreateOrJoinRoomPage()),
                                  (route) => false,
                            );
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Event Room',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                        ),
                        SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(roomName, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 10),
                        Text('Room Code: $eventCode', style: TextStyle(fontSize: 16, color: Colors.white)),
                        Text('Host: $hostName', style: TextStyle(fontSize: 16, color: Colors.white)),
                        if (hostPhotoUrl != null)
                          CircleAvatar(backgroundImage: NetworkImage(hostPhotoUrl), radius: 30),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20.0),
                      children: [
                        ElevatedButton(
                          onPressed: () => _uploadPhoto(context, currentUserId, username),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                          child: Text("Upload Photo", style: TextStyle(color: Colors.white)),
                        ),
                        if (isHost)
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ArrangedPhotoPage(eventCode: eventCode)),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                            child: Text("Arrange Photos", style: TextStyle(color: Colors.white)),
                          ),
                        if (isHost)
                          ElevatedButton(
                            onPressed: () => _showDeleteRoomDialog(context),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: Text("Delete Room"),
                          ),
                        Text('Guests:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        ...guestList.map((guest) => ListTile(
                          leading: guest['guestPhotoUrl'] != null
                              ? CircleAvatar(backgroundImage: NetworkImage(guest['guestPhotoUrl']))
                              : CircleAvatar(child: Icon(Icons.person)),
                          title: Text(guest['guestName'], style: TextStyle(color: Colors.white)),
                        )).toList(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
