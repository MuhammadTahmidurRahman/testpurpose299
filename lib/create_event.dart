import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'eventroom.dart';
import 'join_event.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateEventPage extends StatefulWidget {
  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  String _eventCode = '';
  bool _isCodeGenerated = false;
  GlobalKey _qrKey = GlobalKey();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  String _generateEventCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    return String.fromCharCodes(
        Iterable.generate(8, (_) => chars.codeUnitAt(Random().nextInt(chars.length))));
  }

  void _generateQrCode() {
    setState(() {
      _eventCode = _generateEventCode();
      _isCodeGenerated = true;
    });
  }

  Future<void> _saveQrCode() async {
    try {
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code.png');
      await file.writeAsBytes(buffer);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('QR Code saved at ${file.path}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save QR Code: $e')));
    }
  }

  Future<void> _createRoomInFirebase(String roomName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    final name = currentUser?.displayName ?? 'Unknown';
    final photoUrl = currentUser?.photoURL ?? '';
    final email = currentUser?.email ?? 'unknown@example.com';

    // Generate a sanitized composite key
    final sanitizedEmail = email.replaceAll('.', '_');
    final compositeKey = '${_eventCode}_${roomName}_${sanitizedEmail}_${name}';

    // Reference to the room in Firebase (event room directly under eventCode)
    final roomRef = _databaseRef.child("rooms/$_eventCode");

    // Check if the room already exists
    final snapshot = await roomRef.get();
    if (snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room code already exists!")));
      return;
    }

    // Save the event room details under rooms/$eventCode
    await roomRef.set({
      'eventCode': _eventCode, // Store event code here
      'roomName': roomName,    // Room name
    });

    // Save the host's information under rooms/$eventCode/host/$compositeKey
    await _databaseRef.child("rooms/$_eventCode/host/$compositeKey").set({
      'hostId': uid,
      'hostName': name,
      'hostPhotoUrl': photoUrl,
      'hostEmail': sanitizedEmail,
      'roomName': roomName,
    });

    // Listen for updates in the Firebase user profile and update the host's data if necessary
    FirebaseAuth.instance.userChanges().listen((user) async {
      if (user != null && user.uid == uid) {  // Only update if the current user is the host
        final updatedName = user.displayName ?? name;
        final updatedPhotoUrl = user.photoURL ?? photoUrl;

        // Update host information under the composite key path
        await _databaseRef.child("rooms/$_eventCode/host/$compositeKey").update({
          'hostName': updatedName,
          'hostPhotoUrl': updatedPhotoUrl,
        });
      }
    });

    // Navigate to the event room
    _navigateToEventRoom();
  }

  void _promptRoomName() {
    showDialog(
      context: context,
      builder: (context) {
        String roomName = '';
        return AlertDialog(
          title: Text("Set Room Name"),
          content: TextField(
            onChanged: (value) => roomName = value,
            decoration: InputDecoration(hintText: "Enter room name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (roomName.isNotEmpty) {
                  Navigator.pop(context);
                  _createRoomInFirebase(roomName);
                }
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _navigateToEventRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EventRoom(eventCode: _eventCode)),
    );
  }

  void _navigateToJoinEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JoinEventPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,  // Makes the body extend under the AppBar
      appBar: AppBar(
        title: Text(
          'Create a Room',
          style: TextStyle(
            fontSize: 24,        // Larger font size
            fontWeight: FontWeight.bold,  // Bold text
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Set the background image and make it cover the whole screen
          Image.asset(
            'assets/hpbg1.png',
            fit: BoxFit.cover,
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isCodeGenerated)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _generateQrCode,
                            child: Text('Create Code', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            ),
                          ),
                        ),
                      SizedBox(height: 20),

                      if (_eventCode.isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_eventCode, style: TextStyle(fontSize: 24)),
                              IconButton(
                                icon: Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _eventCode));
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied to clipboard!')));
                                },
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 20),

                      if (_eventCode.isNotEmpty)
                        Column(
                          children: [
                            RepaintBoundary(
                              key: _qrKey,
                              child: Container(
                                height: 150,
                                width: 150,
                                child: PrettyQr(
                                  data: _eventCode,
                                  size: 150.0,
                                  roundEdges: true,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            IconButton(
                              icon: Icon(Icons.download),
                              onPressed: _saveQrCode,
                            ),
                          ],
                        ),

                      SizedBox(height: 20),

                      if (_eventCode.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _promptRoomName,
                            child: Text('Create Room', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            ),
                          ),
                        ),
                      SizedBox(height: 10),

                      if (_eventCode.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _navigateToJoinEvent,
                            child: Text('Join Room', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            ),
                          ),
                        ),
                      SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Back to Room Selection', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
