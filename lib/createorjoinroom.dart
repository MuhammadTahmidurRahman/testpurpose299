import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'create_event.dart';
import 'join_event.dart';
import 'profile.dart';
import 'eventroom.dart';

class CreateOrJoinRoomPage extends StatefulWidget {
  @override
  _CreateOrJoinRoomPageState createState() => _CreateOrJoinRoomPageState();
}

class _CreateOrJoinRoomPageState extends State<CreateOrJoinRoomPage> {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, String>> rooms = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchRoomsFromFirebase();
    _listenForRoomDeletions();
  }

  // Fetch rooms from Firebase Realtime Database
  Future<void> _fetchRoomsFromFirebase() async {
    try {
      final DatabaseReference roomRef = FirebaseDatabase.instance.ref('rooms');
      final snapshot = await roomRef.get();

      if (snapshot.exists) {
        List<Map<String, String>> fetchedRooms = [];

        for (var child in snapshot.children) {
          final roomData = child.value as Map<dynamic, dynamic>;
          final String roomCode = child.key!;
          final String roomName = roomData['roomName']?.toString() ?? 'Unknown Room';
          final hostData = roomData['host'] as Map<dynamic, dynamic>?;
          bool isUserInRoom = false;
          String hostName = 'Unknown Host';

          if (hostData != null) {
            for (var hostEntry in hostData.values) {
              final hostDetails = hostEntry as Map<dynamic, dynamic>;
              final String? hostId = hostDetails['hostId'];
              hostName = hostDetails['hostName']?.toString() ?? 'Unknown Host';

              if (hostId == user?.uid) {
                isUserInRoom = true;
              }
            }
          }

          final guestsData = roomData['guests'] as Map<dynamic, dynamic>?;
          if (!isUserInRoom && guestsData != null) {
            for (var guestEntry in guestsData.values) {
              final guestDetails = guestEntry as Map<dynamic, dynamic>;
              final String? guestId = guestDetails['guestId'];

              if (guestId == user?.uid) {
                isUserInRoom = true;
                break;
              }
            }
          }

          if (isUserInRoom) {
            fetchedRooms.add({
              'roomCode': roomCode,
              'roomName': roomName,
              'hostName': hostName,
            });
          }
        }

        setState(() {
          rooms = fetchedRooms;
          _isLoading = false;
        });
      } else {
        setState(() {
          rooms = [];
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch rooms. Please try again later.';
      });
    }
  }

  // Listen for room deletions from Firebase
  void _listenForRoomDeletions() {
    final DatabaseReference roomRef = FirebaseDatabase.instance.ref('rooms');
    roomRef.onChildRemoved.listen((event) {
      final String deletedRoomCode = event.snapshot.key!;
      setState(() {
        rooms.removeWhere((room) => room['roomCode'] == deletedRoomCode);
      });
    });
  }

  // Function to handle bottom navigation bar tap
  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // Navigate to the EventRoom page when a room is tapped
  void _navigateToEventRoom(String roomCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRoom(eventCode: roomCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hpbg1.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
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
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _errorMessage.isNotEmpty
                    ? Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  ),
                )
                    : Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      return _buildRoomCard(
                        rooms[index]['roomName']!,
                        rooms[index]['hostName']!,
                        rooms[index]['roomCode']!,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
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
  Widget _buildRoomCard(String roomName, String hostName, String roomCode) {
    return GestureDetector(
      onTap: () {
        _navigateToEventRoom(roomCode);
      },
      child: Card(
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
          subtitle: Text('Hosted by: $hostName'),
        ),
      ),
    );
  }
}
