import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'createorjoinroom.dart'; // Ensure this import is correct for CreateOrJoinRoomPage

class EventRoom extends StatelessWidget {
  final String eventCode;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  EventRoom({required this.eventCode});

  // Delete room function
  Future<void> _deleteRoom() async {
    await _databaseRef.child("rooms/$eventCode").remove();
  }

  // Upload photo function
  Future<void> _uploadPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Implement upload logic to Firebase or display image.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String currentUserId = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Event Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Navigate back to CreateOrJoinRoomPage and remove all previous routes
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => CreateOrJoinRoomPage()), // Ensure this is the correct route
                  (route) => false, // Remove all previous routes in the stack
            );
          },
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hpbg1.png',
            fit: BoxFit.cover,
          ),
          FutureBuilder<DataSnapshot>(
            future: _databaseRef.child("rooms/$eventCode").get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Error loading room data"));

              final roomData = snapshot.data!.value as Map<dynamic, dynamic>? ?? {};

              // Get room name
              final roomName = roomData['roomName'] ?? 'No Room Name';

              // Host information
              String hostName = 'Unknown Host';
              String? hostPhotoUrl;
              bool isHost = false;

              final hostMap = roomData['host'] as Map<dynamic, dynamic>? ?? {};
              if (hostMap.isNotEmpty) {
                for (var entry in hostMap.entries) {
                  final host = entry.value as Map<dynamic, dynamic>;
                  hostName = host['hostName'] ?? 'Unknown Host';
                  hostPhotoUrl = host['hostPhotoUrl'];
                  if (host['hostId'] == currentUserId) {
                    isHost = true;
                  }
                  break; // Since there's only one host, we break after the first entry
                }
              }

              // Retrieve guests data and handle guest information correctly
              final guestsData = roomData['guests'] as Map<dynamic, dynamic>? ?? {};
              List<Map<String, dynamic>> guestList = [];
              for (var entry in guestsData.entries) {
                final guest = entry.value as Map<dynamic, dynamic>?;
                if (guest != null) {
                  final guestName = guest['guestName'] ?? 'Unknown Guest';
                  final guestPhotoUrl = guest['guestPhotoUrl'];
                  guestList.add({
                    'guestName': guestName,
                    'guestPhotoUrl': guestPhotoUrl,
                  });
                }
              }

              return Column(
                children: [
                  // Room details section at the top
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          roomName,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Room Code: $eventCode',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        Text(
                          'Host: $hostName', // Display host's name from Firebase
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        if (hostPhotoUrl != null)
                          CircleAvatar(
                            backgroundImage: NetworkImage(hostPhotoUrl), // Display host's photo from Firebase
                            radius: 30,
                          ),
                      ],
                    ),
                  ),
                  // Main content area
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _uploadPhoto,
                          child: Text("Upload Photo"),
                        ),
                        if (isHost)
                          ElevatedButton(
                            onPressed: _deleteRoom,
                            child: Text("Delete Room"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        // Guests section
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: guestList.isEmpty
                              ? Text(
                            'No guests in this room',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guests',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 10),
                              // Display guest list excluding the host
                              ...guestList.where((guest) {
                                return guest['guestName'] != hostName; // Don't display the host in the guests section
                              }).map((guest) {
                                return ListTile(
                                  leading: guest['guestPhotoUrl'] != null
                                      ? CircleAvatar(backgroundImage: NetworkImage(guest['guestPhotoUrl']))
                                      : CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(guest['guestName'], style: TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
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
