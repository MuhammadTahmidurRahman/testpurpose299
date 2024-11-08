import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'eventroom.dart';

class JoinEventPage extends StatefulWidget {
  @override
  _JoinEventPageState createState() => _JoinEventPageState();
}

class _JoinEventPageState extends State<JoinEventPage> {
  MobileScannerController cameraController = MobileScannerController();
  String scannedCode = '';
  String enteredCode = '';
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  User? user = FirebaseAuth.instance.currentUser; // Current logged in user
  String userName = '';
  String userEmail = '';
  String userPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    if (user != null) {
      userName = user!.displayName ?? 'Guest';
      userEmail = user!.email ?? 'guest@example.com';
      userPhotoUrl = user!.photoURL ?? '';  // Default photo URL
    }
  }

  Future<void> _joinRoomAsGuest(String eventCode, String roomName) async {
    if (user == null) {
      // Handle case where user is not logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to join the room!')),
      );
      return;
    }

    // Guest data including the guestId (user's UID)
    final guestData = {
      'guestId': user!.uid,  // Add guestId field
      'guestName': userName,
      'guestEmail': userEmail,
      'guestPhotoUrl': userPhotoUrl,
    };

    // Create a composite key for the guest, replacing '.' with '_'
    String sanitizedEmail = userEmail.replaceAll('.', '_');  // Replace '.' with '_'
    String compositeKey = '${eventCode}_${roomName}_${sanitizedEmail}_${userName}';

    // Save the guest data to Firebase under the event code and composite key
    await _databaseRef.child('rooms/$eventCode/guests/$compositeKey').set(guestData);

    // Listen for updates in the Firebase user profile and update the guest data if necessary
    FirebaseAuth.instance.userChanges().listen((user) async {
      if (user != null) {
        final updatedName = user.displayName ?? '';
        final updatedPhotoUrl = user.photoURL ?? '';

        await _databaseRef.child('rooms/$eventCode/guests/$compositeKey').update({
          'guestName': updatedName,
          'guestPhotoUrl': updatedPhotoUrl,
        });
      }
    });

    // Navigate to the event room
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EventRoom(eventCode: eventCode),
      ),
    );
  }

  // Function to handle QR scanning and event code entry
  Future<void> _navigateToEventRoom(String code) async {
    final snapshot = await _databaseRef.child('rooms/$code').get();

    if (snapshot.exists) {
      final roomData = snapshot.value as Map<dynamic, dynamic>;
      final roomName = roomData['roomName'] ?? 'No Room Name';
      await _joinRoomAsGuest(code, roomName);  // Join the room as a guest
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room does not exist!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Navigate back to the previous page
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
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_rounded,
                  size: 120,
                  color: Colors.black, // Updated to black
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) {
                          return Dialog(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (scannedCode.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Scanned Code: $scannedCode',
                                      style: TextStyle(fontSize: 16, color: Colors.black),
                                    ),
                                  ),
                                Container(
                                  width: 300,
                                  height: 400,
                                  child: MobileScanner(
                                    controller: cameraController,
                                    onDetect: (capture) {
                                      final List<Barcode> barcodes = capture.barcodes;
                                      if (barcodes.isNotEmpty) {
                                        final String? code = barcodes.first.rawValue;
                                        if (code != null && code != scannedCode) {
                                          setState(() {
                                            scannedCode = code;
                                          });
                                          Future.delayed(Duration(seconds: 1), () {
                                            _navigateToEventRoom(scannedCode);
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    backgroundColor: Colors.black, // Black background
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Scan to join',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  onChanged: (value) {
                    enteredCode = value.trim();
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Enter event code to join',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    _navigateToEventRoom(enteredCode);  // Navigate using entered code
                  },
                  child: Text(
                    'Go to EventRoom',
                    style: TextStyle(fontSize: 18, color: Colors.white), // Ensure white text
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, // Black button
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
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