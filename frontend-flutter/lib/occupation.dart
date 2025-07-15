import 'package:flutter/material.dart';

class OccupationFilterPage extends StatefulWidget {
  final Function(List<String>) onOccupationSelected;
  final List<String> initialOccupations;

  const OccupationFilterPage({
    super.key,
    required this.onOccupationSelected,
    required this.initialOccupations,
  });

  @override
  _OccupationFilterPageState createState() => _OccupationFilterPageState();
}

class _OccupationFilterPageState extends State<OccupationFilterPage> {
  List<String> _selectedOccupations = [];

  final List<String> occupations = [
    'sweepres',
    'Backend Developer',
    'Mobile Developer',
    'Tester',
    'Peoples team',
    'Finance',
    'Devops',
    
  ];

  @override
  void initState() {
    super.initState();
    _selectedOccupations = List.from(widget.initialOccupations);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // Light background
      appBar: AppBar(
        automaticallyImplyLeading: false, // Disable default back arrow
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding( // Add padding to the left of the Occupation heading
              padding: EdgeInsets.all(20), // Adjust the padding value as needed
              child: Text(
                'Occupation',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: occupations.length,
                itemBuilder: (context, index) {
                  final occupation = occupations[index];
                  return CheckboxListTile(
                    title: Text(occupation),
                    value: _selectedOccupations.contains(occupation),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _selectedOccupations.add(occupation);
                        } else {
                          _selectedOccupations.remove(occupation);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.deepPurple, // Checkbox color
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  widget.onOccupationSelected(_selectedOccupations);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 20),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}