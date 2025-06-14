import 'package:flutter/material.dart';

class AgeFilterPage extends StatefulWidget {
  final Function(int) onAgeSelected;
  final int initialAge;

  const AgeFilterPage({super.key, required this.onAgeSelected, required this.initialAge});

  @override
  _AgeFilterPageState createState() => _AgeFilterPageState();
}

class _AgeFilterPageState extends State<AgeFilterPage> {
  late double _selectedAge;

  @override
  void initState() {
    super.initState();
    _selectedAge = widget.initialAge.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2), // Light background
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(), // Remove the leading icon
        title: const Text(
          'Age',
          style: TextStyle(
            color: Colors.black,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20), // Keep horizontal padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Slider on Top
            Slider(
              min: 18,
              max: 60,
              value: _selectedAge,
              onChanged: (value) {
                setState(() {
                  _selectedAge = value;
                });
              },
              // Styling the Slider
              activeColor: const Color(0xFF9C7AF6),
              inactiveColor: const Color(0xFFD3D3D3),
              thumbColor: const Color(0xFF9C7AF6), // Purple thumb color
            ),
            // Labels directly below the slider
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('18+', style: TextStyle(fontSize: 14)),
                Text('60', style: TextStyle(fontSize: 14)),
              ],
            ),
            // Display selected age
            Text(
              '${_selectedAge.toInt()}',
              style: const TextStyle(fontSize: 18),
            ),
            const Spacer(), // Pushes the button to the bottom without overflow

            // Save Button on Bottom
            ElevatedButton(
              onPressed: () {
                widget.onAgeSelected(_selectedAge.toInt());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,  // Purple button color
                padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),  // Rounded button
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
