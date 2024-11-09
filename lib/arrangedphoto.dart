import 'package:flutter/material.dart';
import 'eventroom.dart';

class ArrangedPhotoPage extends StatelessWidget {
  final String eventCode;

  ArrangedPhotoPage({required this.eventCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/hpbg1.png',
            fit: BoxFit.cover,
          ),
          Column(
            children: [
              // App Bar with Back Button and Title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Back Button
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    // Title
                    Expanded(
                      child: Text(
                        'Arranged Photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    // Placeholder for alignment
                    SizedBox(width: 48), // To align with the back button size
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'This is a placeholder for the Arranged Photo page.',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
