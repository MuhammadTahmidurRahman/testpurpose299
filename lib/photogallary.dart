import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PhotoGalleryPage extends StatefulWidget {
  final String eventCode;
  final String folderName;
  final String userId;

  PhotoGalleryPage({
    required this.eventCode,
    required this.folderName,
    required this.userId,
  });

  @override
  _PhotoGalleryPageState createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<String> _photoUrls = [];

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please sign in to view photos.")),
      );
      return;
    }

    try {
      final DatabaseReference ref = FirebaseDatabase.instance.ref();

      // Fetch the hostId from the event data
      final DataSnapshot hostIdSnapshot = await ref
          .child("rooms")
          .child(widget.eventCode)
          .child("hostId")
          .get();

      if (!hostIdSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Event data not found.")),
        );
        return;
      }

      final String hostId = hostIdSnapshot.value as String;
      print("Host ID: $hostId");

      // Check if the current user is the host
      final bool isHost = user.uid == hostId;

      // Only allow access to the user's specific folder, regardless of role
      final DataSnapshot folderPathSnapshot = await ref
          .child("rooms")
          .child(widget.eventCode)
          .child("participants")
          .child(widget.userId)
          .child("folderPath")
          .get();

      if (!folderPathSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photo folder path not found.")),
        );
        return;
      }

      final String folderPath = folderPathSnapshot.value as String;
      print("Fetching images from: $folderPath");

      // Ensure that only the host accesses host's folder path, others access only their own
      if (!isHost && folderPath == "rooms/${widget.eventCode}/$hostId") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Access denied: Cannot view host's uploads.")),
        );
        return;
      }

      // Fetch images only from the user's assigned folder in Firebase Storage
      final ListResult result = await _storage.ref(folderPath).listAll();
      final urls = await Future.wait(result.items.map((item) => item.getDownloadURL()).toList());

      setState(() {
        _photoUrls = urls;
      });
    } catch (e) {
      print("Error loading photos: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading photos")),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo Gallery'),
        backgroundColor: Colors.black,
      ),
      body: _photoUrls.isEmpty
          ? Center(child: Text("No photos uploaded.", style: TextStyle(fontSize: 18)))
          : GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: _photoUrls.length,
        itemBuilder: (context, index) {
          return Image.network(_photoUrls[index], fit: BoxFit.cover);
        },
      ),
    );
  }
}