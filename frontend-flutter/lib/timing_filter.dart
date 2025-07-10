import 'package:flutter/material.dart';

class TimingFilterPage extends StatefulWidget {
  final Function(List<String>) onTimingSelected;
  final List<String> initialTimings;

  const TimingFilterPage({
    super.key,
    required this.onTimingSelected,
    required this.initialTimings,
  });

  @override
  _TimingFilterPageState createState() => _TimingFilterPageState();
}

class _TimingFilterPageState extends State<TimingFilterPage> {
  // Map user-friendly display names to backend values with hourly breakdown
  final Map<String, List<String>> timingMap = {
    'Early Morning ': ['12 AM-1 AM', '1 AM-2 AM', '2 AM-3 AM', '3 AM-4 AM', '4 AM-5 AM', '5 AM-6 AM'],
    'Morning': ['6 AM-7 AM', '7 AM-8 AM', '8 AM-9 AM', '9 AM-10 AM', '10 AM-11 AM', '11 AM-12 PM'],
    'Afternoon': ['12 PM-1 PM', '1 PM-2 PM', '2 PM-3 PM', '3 PM-4 PM', '4 PM-5 PM'],
    'Evening': ['5 PM-6 PM', '6 PM-7 PM', '7 PM-8 PM', '8 PM-9 PM'],
    'Night': ['9 PM-10 PM', '10 PM-11 PM', '11 PM-12 AM'],
  };
  
  // Available display names for UI
  late List<String> availableTimings;
  
  // Selected timings stored in backend format (hourly)
  List<String> selectedTimings = [];

  @override
  void initState() {
    super.initState();
    availableTimings = timingMap.keys.toList();
    
    // Initialize with any provided timings
    selectedTimings = List.from(widget.initialTimings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Timings'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (selectedTimings.isEmpty) {
                  // Select all hourly slots
                  for (var slots in timingMap.values) {
                    selectedTimings.addAll(slots);
                  }
                } else {
                  selectedTimings.clear();
                }
              });
            },
            child: Text(
              selectedTimings.isEmpty ? 'Select All' : 'Clear All',
              style: TextStyle(color: Theme.of(context).primaryTextTheme.titleLarge?.color),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: availableTimings.length,
        itemBuilder: (context, index) {
          final period = availableTimings[index];
          final timeSlots = timingMap[period] ?? [];
          
          // Check if all time slots for this period are selected
          bool allSelected = timeSlots.isNotEmpty && 
              timeSlots.every((slot) => selectedTimings.contains(slot));
          
          // Check if some time slots for this period are selected
          bool someSelected = timeSlots.any((slot) => selectedTimings.contains(slot));
          
          return ExpansionTile(
            title: Text(period),
            subtitle: Text('${timeSlots.length} time slots'),
            leading: Checkbox(
              tristate: true,
              value: allSelected ? true : (someSelected ? null : false),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    // Add all time slots for this period
                    for (String slot in timeSlots) {
                      if (!selectedTimings.contains(slot)) {
                        selectedTimings.add(slot);
                      }
                    }
                  } else {
                    // Remove all time slots for this period
                    selectedTimings.removeWhere((slot) => timeSlots.contains(slot));
                  }
                });
              },
            ),
            children: timeSlots.map((slot) {
              return CheckboxListTile(
                title: Text(slot),
                value: selectedTimings.contains(slot),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      selectedTimings.add(slot);
                    } else {
                      selectedTimings.remove(slot);
                    }
                  });
                },
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList(),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${selectedTimings.length} time slots selected'),
              ElevatedButton(
                onPressed: () {
                  widget.onTimingSelected(selectedTimings);
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Example usage:
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> selectedTimings = [];

  void _applyTimingFilter(List<String> timings) {
    setState(() {
      selectedTimings = timings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Time Filter Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TimingFilterPage(
                      initialTimings: selectedTimings,
                      onTimingSelected: _applyTimingFilter,
                    ),
                  ),
                );
              },
              child: const Text('Select Time Ranges'),
            ),
            const SizedBox(height: 20),
            const Text('Selected times:'),
            Expanded(
              child: ListView.builder(
                itemCount: selectedTimings.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(selectedTimings[index]),
                    dense: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}