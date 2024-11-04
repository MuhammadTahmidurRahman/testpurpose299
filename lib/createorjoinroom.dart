import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import for Firebase Authentication
import 'create_event.dart';  // Create Event Page
import 'join_event.dart';  // Join Event Page
import 'profile.dart';  // Profile Page

class CreateOrJoinRoomPage extends StatefulWidget {
  @override
  _CreateOrJoinRoomPageState createState() => _CreateOrJoinRoomPageState();
}

class _CreateOrJoinRoomPageState extends State<CreateOrJoinRoomPage> {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser; // Get the current logged-in user
  List<String> rooms = ['Room 1', 'Room 2', 'Room 3', 'Room 4', 'Room 5']; // Sample room data

  // Function to handle bottom navigation bar tap
  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()), // Navigate to Profile Page
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hpbg1.png',  // Background image for the page
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
                // Header section
                Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      'My Rooms',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Scrollable room list section
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(rooms[index], user?.displayName ?? 'Unknown Owner');
                    },
                  ),
                ),
                // Create and Join buttons section
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to Create Event page
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CreateEventPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        child: Center(
                          child: Text(
                            'Create Room',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to Join Event page
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => JoinEventPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        child: Center(
                          child: Text(
                            'Join Room',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        onTap: _onItemTapped,
      ),
    );
  }

  // Helper function to build room cards
  Widget _buildRoomCard(String roomName, String ownerName) {
    return Card(
      color: Colors.white.withOpacity(0.85),
      margin: EdgeInsets.symmetric(vertical: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        title: Text(
          roomName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          'Owner: $ownerName',
          style: TextStyle(color: Colors.grey),
        ),
        trailing: Icon(Icons.meeting_room, color: Colors.blueAccent),
      ),
    );
  }
}
