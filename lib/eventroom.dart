import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart'; // Ensure this import is present
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:permission_handler/permission_handler.dart';
import 'createorjoinroom.dart';
import 'arrangedphoto.dart';
//import 'package:cloud_firestore/firebase_firestore.dart';

class EventRoom extends StatefulWidget {
  final String eventCode;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  EventRoom({required this.eventCode});

  @override
  _EventRoomState createState() => _EventRoomState();
}

class _EventRoomState extends State<EventRoom> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late DatabaseReference _participantsRef;
  Map<dynamic, dynamic> roomData = {};
  List<Map<String, dynamic>> guestList = [];
  String hostName = 'Unknown Host';
  String? hostPhotoUrl;
  bool hostHasUploadedPhotos = false;

  @override
  void initState() {
    super.initState();
    _participantsRef = _databaseRef.child("rooms/${widget.eventCode}/participants");
    _fetchRoomData();
    _setupRealTimeListeners();
  }

  Future<void> _fetchRoomData() async {
    try {
      final snapshot = await _databaseRef.child("rooms/${widget.eventCode}").get();
      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          roomData = snapshot.value as Map<dynamic, dynamic>;
        });

        final hostId = roomData['hostId'];
        final participants = roomData['participants'] as Map<dynamic, dynamic>? ?? {};

        if (participants.containsKey(hostId)) {
          final hostData = participants[hostId] as Map<dynamic, dynamic>;
          setState(() {
            hostName = hostData['name'] ?? 'Unknown Host';
            hostPhotoUrl = hostData['photoUrl'];
            hostHasUploadedPhotos = hostData['folderPath'] != null;
          });
        }

        _fetchGuestList(participants, hostId);
      }
    } catch (e) {
      print("Error fetching room data: $e");
    }
  }

  void _fetchGuestList(Map<dynamic, dynamic>? participants, String hostId) {
    if (participants == null) return;

    List<Map<String, dynamic>> tempGuestList = [];
    participants.forEach((participantId, participantData) {
      if (participantId != hostId) {
        final data = participantData as Map<dynamic, dynamic>;
        tempGuestList.add({
          'guestId': participantId,
          'guestName': data['name'] ?? 'Unknown Guest',
          'guestPhotoUrl': data['photoUrl'],
          'guestUploadedPhotoFile': data['folderPath'],
        });
      }
    });
    setState(() {
      guestList = tempGuestList;
    });
  }

  void _setupRealTimeListeners() {
    // Listen for changes in participants
    _participantsRef.onChildChanged.listen((event) {
      final participantId = event.snapshot.key;
      final updatedData = event.snapshot.value as Map<dynamic, dynamic>;

      setState(() {
        if (participantId == roomData['hostId']) {
          // Update host data
          hostName = updatedData['name'] ?? 'Unknown Host';
          hostPhotoUrl = updatedData['photoUrl'];
          hostHasUploadedPhotos = updatedData['folderPath'] != null;
        } else {
          // Update guest data
          guestList = guestList.map((guest) {
            if (guest['guestId'] == participantId) {
              return {
                'guestId': guest['guestId'],
                'guestName': updatedData['name'] ?? guest['guestName'],
                'guestPhotoUrl': updatedData['photoUrl'],
                'guestUploadedPhotoFile': updatedData['folderPath'],
              };
            }
            return guest;
          }).toList();
        }
      });
    });

    // Removed the listener for sortPhotoRequest as per instructions
    // _databaseRef.child("rooms/${widget.eventCode}/host/sortPhotoRequest").onValue.listen((event) {
    //   // Handle real-time updates for sortPhotoRequest if needed
    //   // Currently left empty as per original code
    // });
  }

  Future<List<String>> _fetchImages(String folderPath) async {
    try {
      final ref = _storage.ref(folderPath);
      final listResult = await ref.listAll();

      List<String> imageUrls = [];
      for (var item in listResult.items) {
        final url = await item.getDownloadURL();
        imageUrls.add(url);
      }
      return imageUrls;
    } catch (e) {
      print('Error fetching images: $e');
      return [];
    }
  }

  Future<void> _downloadImagesAsZip(
      List<String> imageUrls, String participantName, bool isSortedPhoto) async {
    try {
      // Request storage permissions
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        final confirmDownload = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Confirm Download'),
              content: Text('Do you want to download this folder as a ZIP file?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Yes'),
                ),
              ],
            );
          },
        );

        if (confirmDownload == true) {
          final tempDir = await getTemporaryDirectory();
          final zipFilePath = '${tempDir.path}/images.zip';

          final encoder = ZipFileEncoder();
          encoder.create(zipFilePath);

          for (int i = 0; i < imageUrls.length; i++) {
            final imageUrl = imageUrls[i];
            final imageName = 'image_$i.jpg';

            final response = await HttpClient().getUrl(Uri.parse(imageUrl));
            final tempFile = File('${tempDir.path}/$imageName');
            final imageStream = await response.close();
            await imageStream.pipe(tempFile.openWrite());

            encoder.addFile(tempFile);
            await tempFile.delete();
          }

          encoder.close();

          String zipFileName;
          if (isSortedPhoto) {
            zipFileName = 'sortedphoto.zip';
          } else {
            // Ensure participantName does not contain any invalid characters for filenames
            String sanitizedParticipantName = participantName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
            zipFileName = '${sanitizedParticipantName}_uploaded.zip';
          }

          // Define the download path based on the platform
          String downloadsPath;
          if (Platform.isAndroid) {
            downloadsPath = '/storage/emulated/0/Download';
          } else if (Platform.isIOS) {
            downloadsPath = (await getApplicationDocumentsDirectory()).path;
          } else {
            downloadsPath = tempDir.path; // Fallback for other platforms
          }

          final savePath = '$downloadsPath/$zipFileName';

          final downloadsDir = Directory(downloadsPath);
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          final savedFile = await File(zipFilePath).copy(savePath);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ZIP file saved to ${savedFile.path}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage permission is required.')),
        );
      }
    } catch (e) {
      print('Error downloading images as ZIP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save ZIP file.')),
      );
    }
  }

  void _showNoPhotosMessage() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('No Photos'),
          content: Text('No photos sorted for this participant.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showImageGallery(List<String> images, String participantName, bool isSortedPhoto) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Column(
            children: [
              // Close button at upper right corner
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              Expanded(
                child: images.isNotEmpty
                    ? GridView.builder(
                  padding: EdgeInsets.all(8.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Image.network(images[index], fit: BoxFit.cover);
                  },
                )
                    : Center(child: Text('No Photos Uploaded')),
              ),
              if (images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      await _downloadImagesAsZip(images, participantName, isSortedPhoto);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                    child: Text(
                      'Download All',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String currentUserId = user?.uid ?? '';
    final String username = user?.displayName ?? 'Guest';
    final bool isHost = currentUserId == roomData['hostId'];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/hpbg1.png', fit: BoxFit.cover),
          Column(
            children: [
              // Top Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20.0),
                child: Row(
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
                    SizedBox(width: 40), // Spacer to balance the back button
                  ],
                ),
              ),
              // Center-Aligned Room and Host Information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // Center alignment
                  children: [
                    Text(
                      roomData['roomName'] ?? 'No Room Name',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                      textAlign: TextAlign.center, // Center the text
                    ),
                    SizedBox(height: 5),
                    Text('Room Code: ${widget.eventCode}', style: TextStyle(fontSize: 16, color: Colors.black)),
                    Text('Host: $hostName', style: TextStyle(fontSize: 16, color: Colors.black)),
                    if (hostPhotoUrl != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: CircleAvatar(backgroundImage: NetworkImage(hostPhotoUrl!), radius: 30),
                      ),
                    SizedBox(height: 10),
                    // **Host Folder Icon (visible to all if host has uploaded photos)**
                    if (hostHasUploadedPhotos)
                      GestureDetector(
                        onTap: isHost
                            ? () {
                          // Host can access their own folder
                          _openPhotoGallery(context, 'host', roomData['hostId'], false);
                        }
                            : null, // Guests cannot access host's folder
                        child: Icon(
                          Icons.folder,
                          color: isHost ? Colors.black : Colors.white, // Greyed out if not clickable
                          size: 30,
                        ),
                      ),
                    SizedBox(height: 20),
                    // **Added Semi-Transparent Black Layer Behind Buttons**
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5), // Semi-transparent black layer
                        borderRadius: BorderRadius.circular(10.0), // Optional: Rounded corners
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.0), // Padding for vertical spacing
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Arrange Photo Button
                          if (isHost)
                            IconButton(
                              icon: Icon(Icons.compare_arrows, color: Colors.white),
                              onPressed: () {
                                // Navigate to ArrangedPhotoPage without incrementing sortPhotoRequest
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ArrangedPhotoPage(eventCode: widget.eventCode)),
                                );
                              },
                            ),
                          // **Added Vertical Spacing Between Buttons**
                          if (isHost)
                            SizedBox(width: 20), // Horizontal spacing instead of Vertical since Row is horizontal
                          // Upload Photo Button
                          IconButton(
                            icon: Icon(Icons.upload, color: Colors.white),
                            onPressed: () => _uploadPhoto(context, currentUserId, username, isHost),
                          ),
                          // **Added Vertical Spacing Between Buttons**
                          if (isHost)
                            SizedBox(width: 20), // Horizontal spacing
                          // Delete Room Button
                          if (isHost)
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.white),
                              onPressed: () => _showDeleteRoomDialog(context),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Guest List with Scrollbar
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true, // Ensure scrollbar is visible when needed
                  thickness: 6.0, // Thickness of the scrollbar
                  radius: Radius.circular(10), // Rounded corners for scrollbar
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
                    itemCount: guestList.length + 1, // +1 for the "Guests:" header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Text(
                            'Guests:',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final guest = guestList[index - 1];
                      bool hasUploadedPhoto = guest['guestUploadedPhotoFile'] != null;
                      bool isCurrentUserGuest = guest['guestId'] == currentUserId;

                      return ListTile(
                        leading: guest['guestPhotoUrl'] != null
                            ? CircleAvatar(backgroundImage: NetworkImage(guest['guestPhotoUrl']!), radius: 25)
                            : CircleAvatar(backgroundColor: Colors.grey, radius: 25),
                        title: Text(guest['guestName'], style: TextStyle(color: Colors.black)),
                        trailing: hasUploadedPhoto
                            ? GestureDetector(
                          onTap: (isHost || isCurrentUserGuest)
                              ? () async {
                            String folderPath = 'rooms/${widget.eventCode}/${guest['guestId']}/';
                            List<String> images = await _fetchImages(folderPath);
                            if (images.isEmpty) {
                              _showNoPhotosMessage();
                            } else {
                              _showImageGallery(images, guest['guestName'], false);
                            }
                          }
                              : null, // Non-clickable for guests who are not the current user or host
                          child: Icon(
                            Icons.folder,
                            color: (isHost || isCurrentUserGuest) ? Colors.black : Colors.white,
                          ),
                        )
                            : SizedBox.shrink(), // No folder icon if no photos
                      );
                    },
                  ),
                ),
              ),
              // Sorted Photo Button positioned at the bottom center
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSortedPhotos(context, currentUserId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    icon: Icon(Icons.sort, color: Colors.white),
                    label: Text('Sorted Photo', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _uploadPhoto(BuildContext context, String userId, String username, bool isHost) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    String baseFolderPath = 'rooms/${widget.eventCode}/$userId/';
    final filePath = '${baseFolderPath}${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(filePath);

    final uploadTask = ref.putFile(File(image.path));

    await uploadTask.whenComplete(() async {
      if (isHost) {
        // Set folderPath to 'rooms/eventcode/hostId/'
        _databaseRef.child("rooms/${widget.eventCode}/hostUploadedPhotoFolderPath").set(baseFolderPath);
      } else {
        // Set folderPath to 'rooms/eventcode/userId/'
        _databaseRef.child("rooms/${widget.eventCode}/participants/$userId/folderPath").set(baseFolderPath);
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo uploaded successfully!')));
    }).catchError((error) {
      print('Upload failed: $error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo upload failed.')));
    });
  }

  void _openPhotoGallery(BuildContext context, String userType, String userId, bool isSortedPhoto) async {
    String folderPath;
    if (isSortedPhoto) {
      folderPath = 'rooms/${widget.eventCode}/$userId/photos/';
    } else {
      folderPath = 'rooms/${widget.eventCode}/$userId/';
    }

    final images = await _fetchImages(folderPath);
    if (images.isEmpty) {
      _showNoPhotosMessage();
    } else {
      // Determine participant's name for zip naming
      String participantName;
      if (userType == 'host') {
        participantName = hostName;
      } else {
        final guest = guestList.firstWhere(
              (guest) => guest['guestId'] == userId,
          orElse: () => {'guestName': 'Unknown Guest'},
        );
        participantName = guest['guestName'];
      }

      _showImageGallery(images, participantName, isSortedPhoto);
    }
  }

  void _showDeleteRoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Room'),
          content: Text('Are you sure you want to delete this room?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _databaseRef.child("rooms/${widget.eventCode}").remove();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room deleted successfully.')));
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => CreateOrJoinRoomPage()),
                        (route) => false,
                  );
                } catch (e) {
                  print('Error deleting room: $e');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete room.')));
                }
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  void _handleSortedPhotos(BuildContext context, String currentUserId) async {
    String participantId;
    bool isSortedPhoto = true;
    if (currentUserId == roomData['hostId']) {
      participantId = roomData['hostId'];
    } else {
      participantId = currentUserId;
    }
    final folderPath = 'rooms/${widget.eventCode}/$participantId/photos/';
    final images = await _fetchImages(folderPath);
    if (images.isEmpty) {
      _showNoPhotosMessage();
    } else {
      // Determine participant's name for zip naming
      String participantName;
      if (currentUserId == roomData['hostId']) {
        participantName = hostName;
      } else {
        final guest = guestList.firstWhere(
              (guest) => guest['guestId'] == participantId,
          orElse: () => {'guestName': 'Unknown Guest'},
        );
        participantName = guest['guestName'];
      }
      _showImageGallery(images, participantName, isSortedPhoto);
    }
  }
}
