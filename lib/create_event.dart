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

class CreateEventPage extends StatefulWidget {
  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  String _eventCode = '';
  bool _isCodeGenerated = false;
  GlobalKey _qrKey = GlobalKey();

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
      appBar: AppBar(
        title: Text('Create a Room'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hpbg1.png',
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                      onPressed: _navigateToEventRoom,
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
        ],
      ),
    );
  }
}
