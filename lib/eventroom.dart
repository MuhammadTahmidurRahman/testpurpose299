import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'createorjoinroom.dart';
import 'arrangedphoto.dart';
import 'photogallary.dart';

class EventRoom extends StatelessWidget {
  final String eventCode;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  EventRoom({required this.eventCode});

  Future<void> _deleteRoom(BuildContext context) async {
    await _databaseRef.child("rooms/$eventCode").remove();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Room has been permanently deleted.')),
    );
  }

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

  Future<void> _uploadPhoto(BuildContext context, String userId, String username, bool isHost) async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      // Show confirmation dialog before uploading
      bool? confirmUpload = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Upload Photos"),
            content: Text("Do you want to upload ${pickedFiles.length} photo(s)?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("No"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text("Yes"),
              ),
            ],
          );
        },
      );

      // Proceed only if the user confirmed
      if (confirmUpload == true) {
        String folderPath = "rooms/$eventCode/$userId";

        for (var file in pickedFiles) {
          String fileName = DateTime.now().millisecondsSinceEpoch.toString();
          File convertedFile = File(file.path);

          final photoRef = _storage.ref('$folderPath/$fileName');
          await photoRef.putFile(convertedFile);
        }

        // Update Firebase Database with the folder path after upload
        await _databaseRef
            .child('rooms/$eventCode/participants/$userId')
            .update({'folderPath': folderPath}); // Ensure only `folderPath` is updated

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pickedFiles.length} photos uploaded successfully!')),
        );
      }
    }
  }

  void _openPhotoGallery(BuildContext context, String folderName, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoGalleryPage(eventCode: eventCode, folderName: folderName, userId: userId),
      ),
    );
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
    final hostId = roomData['hostId'];

    // Fetching host data
    final hostData = roomData['participants'][hostId] as Map<dynamic, dynamic>? ?? {};
    String hostName = hostData['name'] ?? 'Unknown Host';
    String? hostPhotoUrl = hostData['photoUrl'];
    bool isHost = currentUserId == hostId;
    bool hostHasUploadedPhotos = roomData['hostUploadedPhotoFolderPath'] != null;

    // Fetching guests data
    final guestsData = roomData['participants'] as Map<dynamic, dynamic>? ?? {};
    List<Map<String, dynamic>> guestList = [];
    guestsData.forEach((participantId, participantData) {
    if (participantId != hostId) { // Skip the host when listing guests
    final guest = participantData as Map<dynamic, dynamic>;
    guestList.add({
    'guestId': participantId,
    'guestName': guest['name'] ?? 'Unknown Guest',
    'guestPhotoUrl': guest['photoUrl'],
    'guestUploadedPhotoFile': guest['folderPath'], // Adjust to your data structure
    });
    }
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
    if (hostHasUploadedPhotos)
    IconButton(
    icon: Icon(Icons.folder, color: Colors.blue),
    onPressed: () => _openPhotoGallery(context, 'host', hostId),
    ),
    ],
    ),
    ),
    Expanded(
    child: ListView(
    padding: const EdgeInsets.all(20.0),
    children: [
    ElevatedButton(
    onPressed: () => _uploadPhoto(context, currentUserId, username, isHost),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
    child: Text("Upload Photo", style: TextStyle(color: Colors.white)),
    ),
    if (isHost)
    ElevatedButton(
    onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ArrangedPhotoPage(eventCode: eventCode)),
    ),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
    child: Text("Arrange Photo", style: TextStyle(color: Colors.white)),
    ),
    if (isHost)
    ElevatedButton(
    onPressed: () => _showDeleteRoomDialog(context),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
    child: Text("Delete Room"),
    ),
    SizedBox(height: 20),
    Text('Guests:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
    ...guestList.map((guest) {
    bool hasUploadedPhoto = guest['guestUploadedPhotoFile'] != null;
    bool canAccessPhotos = isHost || guest['guestId'] == currentUserId;

    return ListTile(
    leading: guest['guestPhotoUrl'] != null
    ? CircleAvatar(backgroundImage: NetworkImage(guest['guestPhotoUrl']), radius: 25)
        : CircleAvatar(backgroundColor: Colors.grey, radius: 25),
    title: Text(guest['guestName'], style: TextStyle(color: Colors.white)),
    trailing: hasUploadedPhoto
    ? IconButton(
    icon: Icon(Icons.folder, color: Colors.blue),
    onPressed: canAccessPhotos
    ? () => _openPhotoGallery(context, 'guest', guest['guestId'])
        : null,
    )
        : Icon(Icons.photo_outlined, color: Colors.grey),
    );
    }).toList(),
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
