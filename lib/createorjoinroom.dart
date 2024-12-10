import 'dart:ui'; // For BackdropFilter
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

  Future<void> _fetchRoomsFromFirebase() async {
    try {
      final DatabaseReference roomRef = FirebaseDatabase.instance.ref('rooms');
      final snapshot = await roomRef.get();

      if (snapshot.exists) {
        List<Map<String, String>> fetchedRooms = [];

        for (var child in snapshot.children) {
          final roomData = child.value as Map<dynamic, dynamic>;
          final String roomCode = child.key!;
          final String roomName =
              roomData['roomName']?.toString() ?? 'Unknown Room';
          final String? hostId = roomData['hostId']?.toString();
          bool isUserInRoom = false;
          String hostName = 'Unknown Host';

          if (hostId == user?.uid) {
            isUserInRoom = true;
            hostName = roomData['participants'][hostId]['name']?.toString() ??
                'Unknown Host';
          }

          final participantsData =
          roomData['participants'] as Map<dynamic, dynamic>?;
          if (!isUserInRoom && participantsData != null) {
            for (var participantEntry in participantsData.entries) {
              final participantId = participantEntry.key;
              if (participantId == user?.uid) {
                isUserInRoom = true;
                hostName =
                    roomData['participants'][hostId]['name']?.toString() ??
                        'Unknown Host';
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

  void _listenForRoomDeletions() {
    final DatabaseReference roomRef = FirebaseDatabase.instance.ref('rooms');
    roomRef.onChildRemoved.listen((event) {
      final String deletedRoomCode = event.snapshot.key!;
      setState(() {
        rooms.removeWhere((room) => room['roomCode'] == deletedRoomCode);
      });
    });
  }

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
          // Background image
          Image.asset(
            'assets/hpbg1.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
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
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                    ),
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
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, bottom: 90, top: 20),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => CreateEventPage()),
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
                            MaterialPageRoute(
                                builder: (context) => JoinEventPage()),
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
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: BottomNavigationBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
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
                    selectedItemColor: Colors.white,
                    unselectedItemColor: Colors.white, // Ensure unselected items are fully white
                    onTap: _onItemTapped,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(String roomName, String hostName, String roomCode) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.black.withOpacity(0.4),
            ),
            child: ListTile(
              title: Text(
                roomName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                'Hosted by: $hostName',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => _navigateToEventRoom(roomCode),
            ),
          ),
        ),
      ),
    );
  }
}
