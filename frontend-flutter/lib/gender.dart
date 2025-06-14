import 'package:flutter/material.dart';

class GenderFilterPage extends StatefulWidget {
  final Function(List<String>) onGenderSelected;
  final List<String> initialGenders;

  const GenderFilterPage({
    super.key,
    required this.onGenderSelected,
    required this.initialGenders,
  });

  @override
  _GenderFilterPageState createState() => _GenderFilterPageState();
}

class _GenderFilterPageState extends State<GenderFilterPage> {
  List<String> _selectedGenders = [];

  final List<String> genders = ['Male', 'Female', 'Others'];

  @override
  void initState() {
    super.initState();
    _selectedGenders = List.from(widget.initialGenders); // Initialize with the provided initial genders
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2), // Light grey background
      appBar: AppBar(
        automaticallyImplyLeading: false, // Disable default back arrow
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding( // Add padding to the left of the Gender heading
              padding: EdgeInsets.all(18),
              child: Text(
                'Gender',
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: genders.map((gender) {
                  return CheckboxListTile(
                    title: Text(gender),
                    value: _selectedGenders.contains(gender),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedGenders.add(gender);
                        } else {
                          _selectedGenders.remove(gender);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.deepPurple, // Checkbox color
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  widget.onGenderSelected(_selectedGenders);
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