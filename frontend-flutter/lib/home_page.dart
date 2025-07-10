import 'package:flutter/material.dart';
import 'dart:ui'; // Add this import for ImageFilter
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'age_filter.dart';
import 'occupation.dart';
import 'gender.dart';
import 'user_profile.dart';
import 'profile.dart';
import 'timing_filter.dart';
import 'location _filter.dart'; // Fixed import name
import 'pricingPage.dart'; // Import the pricing page
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> applicants = [];
  List<Map<String, dynamic>> filteredApplicants = [];
  int? _selectedAgeFilter;
  List<String> _selectedOccupationFilters = [];
  List<String> _selectedTimingFilters = [];
  List<String> _selectedGenderFilters = [];
  Position? _currentPosition;
  double? _customLatitude;
  double? _customLongitude;
  int _searchRadius = 5000; // Default radius in meters
  String? _landmark;
  bool _useLocationFilter = false;
  bool _isLoading = true;
  final bool _isSubscribed = false; // Track subscription status
  final int _freeApplicantsLimit = 5; // Number of free applicants to show

  @override
  void initState() {
    super.initState();
    _fetchApplicantsData();
  }

  Future<void> _fetchApplicantsData() async {
    try {
      final response = await http.get(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/formdatas'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          applicants = data.map((item) => {
                'name': item['name'] ?? '',
                'age': item['age'] ?? 0,
                'timing': item['timing'] ?? '',
                'occupation': item['occupation'] ?? '',
                'gender': item['gender'] ?? '',
                'location': item['location'] ?? {'latitude': 0.0, 'longitude': 0.0},
                'landmarks': item['landmarks'] ?? '',
              }).toList();
          filteredApplicants = applicants;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load applicants data');
      }
    } catch (error) {
      print('Error fetching applicants data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

 Future<void> _getCurrentLocation() async {
  try {
    setState(() {
      _isLoading = true;
    });
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      setState(() {
        _isLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied. Please enable them.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    
    // Get nearby landmarks
    String? landmarkText;
    try {
      // Try using OpenCage API instead of the geocoding package
      final response = await http.get(
        Uri.parse('https://api.opencagedata.com/geocode/v1/json?q=${position.latitude}+${position.longitude}&key=440c46f29d824bc087c36dc044d089d3&language=en'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          
          // Try to get the most specific location name
          if (result['components'] != null) {
            final components = result['components'];
            
            // Try to find the most specific landmark in order of preference
            landmarkText = components['neighbourhood'] ?? 
                         components['suburb'] ?? 
                         components['town'] ?? 
                         components['city'] ?? 
                         components['county'] ?? 
                         components['state'] ?? 
                         components['country'];
          }
        }
      }
      
      // Fallback to using geocoding package if OpenCage didn't work
      if (landmarkText == null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, 
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Build a list of potential landmark identifiers, filter out nulls and empty strings
          List<String> potentialLandmarks = [
            place.name,
            place.thoroughfare,
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].where((item) => item != null && item.isNotEmpty).map((item) => item!).toList();
          
          if (potentialLandmarks.isNotEmpty) {
            landmarkText = potentialLandmarks.first;
          }
        }
      }
    } catch (e) {
      print('Error getting landmark information: $e');
      // Don't rethrow - we'll continue without landmark info
    }

    setState(() {
      _currentPosition = position;
      _customLatitude = position.latitude;
      _customLongitude = position.longitude;
      _useLocationFilter = true;
      _searchRadius = 5000; // Reset to default when using current location
      _landmark = landmarkText;
      _isLoading = false;
    });
    
    // Apply filters after state is updated
    _applyFilters();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_landmark != null && _landmark!.isNotEmpty 
            ? 'Showing applicants near $_landmark within $_searchRadius meters'
            : 'Showing applicants within $_searchRadius meters of your location'),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    print('Error getting current location: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to get location. Please try again.')),
    );
    setState(() {
      _isLoading = false;
    });
  }
}

  void _openLocationFilterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationFilterPage(
          onLocationSelected: (latitude, longitude, radius, landmark) {
            setState(() {
              _customLatitude = latitude;
              _customLongitude = longitude;
              _searchRadius = radius;
              _landmark = landmark;
              _useLocationFilter = true;
              _applyFilters();
            });
          },
          initialLatitude: _customLatitude,
          initialLongitude: _customLongitude,
          initialRadius: _searchRadius,
          initialLandmark: _landmark,
        ),
      ),
    );
  }

  void _searchApplicants(String searchText) {
    searchText = searchText.toLowerCase();
    _applyFilters(searchText);
  }

  void _applyAgeFilter(int selectedAge) {
    setState(() {
      _selectedAgeFilter = selectedAge;
      _applyFilters();
    });
  }

  void _applyOccupationFilter(List<String> selectedOccupations) {
    setState(() {
      _selectedOccupationFilters = selectedOccupations;
      _applyFilters();
    });
  }

  void _applyTimingFilter(List<String> selectedTimings) {
    setState(() {
      _selectedTimingFilters = selectedTimings;
      _applyFilters();
    });
  }

  void _applyGenderFilter(List<String> selectedGenders) {
    setState(() {
      _selectedGenderFilters = selectedGenders;
      _applyFilters();
    });
  }

  void _clearLocationFilter() {
    setState(() {
      _useLocationFilter = false;
      _landmark = null;
      _customLatitude = null;
      _customLongitude = null;
      _applyFilters();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location filter cleared')),
    );
  }

  void _applyFilters([String searchText = '']) {
    if (searchController.text.isNotEmpty) {
      searchText = searchController.text.toLowerCase();
    }
    
    setState(() {
      filteredApplicants = applicants.where((applicant) {
        // Name filtering
        bool matchesSearch = applicant['name']
            .toString()
            .toLowerCase()
            .contains(searchText.toLowerCase());
        
        // Age filtering
        bool matchesAge = _selectedAgeFilter == null ||
            (applicant['age'] != null && applicant['age'] >= _selectedAgeFilter!);
        
        // Occupation filtering
        bool matchesOccupation = _selectedOccupationFilters.isEmpty ||
            (applicant['occupation'] != null && 
             _selectedOccupationFilters.contains(applicant['occupation']));
        
        // Timing filtering
        bool matchesTiming = _selectedTimingFilters.isEmpty ||
            (applicant['timing'] != null && 
             _selectedTimingFilters.contains(applicant['timing']));
        
        // Gender filtering
        bool matchesGender = _selectedGenderFilters.isEmpty ||
            (applicant['gender'] != null && 
             _selectedGenderFilters.contains(applicant['gender']));

        // Location and landmark filtering
        bool matchesLocation = true;
        if (_useLocationFilter && _customLatitude != null && _customLongitude != null) {
          // First check if the landmark matches
          bool hasMatchingLandmark = false;
          if (_landmark != null && _landmark!.isNotEmpty && 
              applicant['landmarks'] != null && applicant['landmarks'].toString().isNotEmpty) {
            
            // Split the landmarks string and check if any of them match
            List<String> appLandmarks = applicant['landmarks']
                .toString()
                .toLowerCase()
                .split(',')
                .map((l) => l.trim())
                .toList();
                
            String landmarkLower = _landmark!.toLowerCase();
            
            hasMatchingLandmark = appLandmarks.any((landmark) => 
                landmark.contains(landmarkLower) || landmarkLower.contains(landmark));
          }
          
          // If landmark doesn't match, check distance from coordinates
          if (!hasMatchingLandmark) {
            double? appLatitude;
            double? appLongitude;
            
            // Safely extract location data from applicant
            if (applicant['location'] != null) {
              // Handle both double and integer values from the API
              var lat = applicant['location']['latitude'];
              var lng = applicant['location']['longitude'];
              
              if (lat != null) {
                appLatitude = lat is double ? lat : lat.toDouble();
              }
              
              if (lng != null) {
                appLongitude = lng is double ? lng : lng.toDouble();
              }
            }
            
            // Only calculate distance if we have valid coordinates
            if (appLatitude != null && appLongitude != null) {
              double distance = Geolocator.distanceBetween(
                _customLatitude!,
                _customLongitude!,
                appLatitude,
                appLongitude,
              );
              matchesLocation = distance <= _searchRadius;
            } else {
              // If missing coordinates, don't match
              matchesLocation = false;
            }
          }
        }

        return matchesSearch &&
            matchesAge &&
            matchesOccupation &&
            matchesTiming &&
            matchesGender &&
            matchesLocation;
      }).toList();

      // Sort by distance if location filter is active
      if (_useLocationFilter && _customLatitude != null && _customLongitude != null) {
        filteredApplicants.sort((a, b) {
          double? distanceA = _calculateDistance(a);
          double? distanceB = _calculateDistance(b);
          
          if (distanceA == null && distanceB == null) return 0;
          if (distanceA == null) return 1;
          if (distanceB == null) return -1;
          
          return distanceA.compareTo(distanceB);
        });
      }
    });
  }

  // Helper function to calculate distance in a safe way
  double? _calculateDistance(Map<String, dynamic> applicant) {
    if (!_useLocationFilter || 
        _customLatitude == null || 
        _customLongitude == null ||
        applicant['location'] == null) {
      return null;
    }

    double? appLatitude;
    double? appLongitude;
    
    var lat = applicant['location']['latitude'];
    var lng = applicant['location']['longitude'];
    
    if (lat != null) {
      appLatitude = lat is double ? lat : lat.toDouble();
    }
    
    if (lng != null) {
      appLongitude = lng is double ? lng : lng.toDouble();
    }
    
    if (appLatitude == null || appLongitude == null) {
      return null;
    }
    
    return Geolocator.distanceBetween(
      _customLatitude!,
      _customLongitude!,
      appLatitude,
      appLongitude,
    );
  }
  
  // Navigate to pricing page
  void _navigateToPricingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PricingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Home Page'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UserProfilePage()),
              );
            },
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    // Search field with improved styling
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 1.0,
                          ),
                        ),
                      ),
                      onChanged: _searchApplicants,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Location controls with improved layout
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Nearby'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _useLocationFilter && _currentPosition != null ? Colors.green : null,
                            foregroundColor: _useLocationFilter && _currentPosition != null ? Colors.white : null,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _openLocationFilterPage,
                          icon: const Icon(Icons.location_on, size: 18),
                          label: const Text('Custom'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _useLocationFilter && _customLatitude != null && _currentPosition == null ? Colors.green : null,
                            foregroundColor: _useLocationFilter && _customLatitude != null && _currentPosition == null ? Colors.white : null,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        if (_useLocationFilter)
                          IconButton(
                            onPressed: _clearLocationFilter,
                            icon: const Icon(Icons.clear, size: 20),
                            tooltip: 'Clear location filter',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              shape: const CircleBorder(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Filter chips with better scrolling
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Age ${_selectedAgeFilter != null ? "($_selectedAgeFilter+)" : ""}',
                        selected: _selectedAgeFilter != null,
                        onSelected: (selected) {
                          if (selected) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AgeFilterPage(
                                  onAgeSelected: _applyAgeFilter,
                                  initialAge: _selectedAgeFilter ?? 18,
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              _selectedAgeFilter = null;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Occupation${_selectedOccupationFilters.isNotEmpty ? " (${_selectedOccupationFilters.length})" : ""}',
                        selected: _selectedOccupationFilters.isNotEmpty,
                        onSelected: (selected) {
                          if (selected) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OccupationFilterPage(
                                  onOccupationSelected: _applyOccupationFilter,
                                  initialOccupations: _selectedOccupationFilters,
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              _selectedOccupationFilters = [];
                              _applyFilters();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Timing${_selectedTimingFilters.isNotEmpty ? " (${_selectedTimingFilters.length})" : ""}',
                        selected: _selectedTimingFilters.isNotEmpty,
                        onSelected: (selected) {
                          if (selected) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TimingFilterPage(
                                  onTimingSelected: _applyTimingFilter,
                                  initialTimings: _selectedTimingFilters,
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              _selectedTimingFilters = [];
                              _applyFilters();
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Gender${_selectedGenderFilters.isNotEmpty ? " (${_selectedGenderFilters.length})" : ""}',
                        selected: _selectedGenderFilters.isNotEmpty,
                        onSelected: (selected) {
                          if (selected) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GenderFilterPage(
                                  onGenderSelected: _applyGenderFilter,
                                  initialGenders: _selectedGenderFilters,
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              _selectedGenderFilters = [];
                              _applyFilters();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              // Location radius indicator with better styling
              if (_useLocationFilter)
                Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        _landmark != null && _landmark!.isNotEmpty
                            ? 'Near "$_landmark" (${_searchRadius}m)'
                            : 'Within $_searchRadius meters',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
                
              // Main content area with applicant list
              Expanded(
                child: filteredApplicants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _useLocationFilter ? Icons.location_off : Icons.search_off,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _useLocationFilter
                                  ? 'No applicants found in this location'
                                  : 'No applicants match your filters',
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () {
                                // Reset all filters
                                setState(() {
                                  _useLocationFilter = false;
                                  _landmark = null;
                                  _selectedAgeFilter = null;
                                  _selectedOccupationFilters = [];
                                  _selectedTimingFilters = [];
                                  _selectedGenderFilters = [];
                                  searchController.clear();
                                  _applyFilters();
                                });
                              },
                              child: const Text('Clear All Filters'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Show applicants
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              // Only build the visible items (free or subscribed)
                              itemCount: _isSubscribed 
                                  ? filteredApplicants.length 
                                  : (_freeApplicantsLimit < filteredApplicants.length 
                                      ? _freeApplicantsLimit + 2 // +2 for blurred items
                                      : filteredApplicants.length),
                              itemBuilder: (context, index) {
                                // If we're past the free limit and not subscribed, show blurred items
                                if (!_isSubscribed && index >= _freeApplicantsLimit) {
                                  // Show only 2 blurred items max
                                  if (index >= _freeApplicantsLimit + 2) {
                                    return Container(); // Don't show anything
                                  }
                                  
                                  // Create a blurred preview of the next applicants
                                  return Opacity(
                                    opacity: 0.4, // Make it semi-transparent
                                    child: Stack(
                                      children: [
                                        // The applicant card (blurred)
                                        _buildApplicantCard(
                                          filteredApplicants[index],
                                          _calculateDistance(filteredApplicants[index]),
                                        ),
                                        
                                        // Blur overlay with lock icon
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                              child: Container(
                                                color: Colors.transparent,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.lock,
                                                    color: Colors.white.withOpacity(0.8),
                                                    size: 28,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                // Normal applicant card for free or subscribed users
                                final applicant = filteredApplicants[index];
                                final distance = _calculateDistance(applicant);
                                
                                return _buildApplicantCard(applicant, distance);
                              },
                            ),
                          ),
                          
                          // Subscription banner (show only if there are more applicants than the free limit)
                          if (!_isSubscribed && filteredApplicants.length > _freeApplicantsLimit)
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue.shade500, Colors.purple.shade500],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade200.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.visibility,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Unlock ${filteredApplicants.length - _freeApplicantsLimit} More Applicants',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Subscribe to see all ${filteredApplicants.length} applicants!',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _navigateToPricingPage,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.blue.shade700,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'View Subscription Plans',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
  
  // Helper method to create filter chips with consistent style
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.blue.shade800 : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? Colors.blue.shade300 : Colors.transparent,
          width: 1,
        ),
      ),
    );
  }
  
  // Helper method to create applicant cards with consistent style
  Widget _buildApplicantCard(Map<String, dynamic> applicant, double? distance) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(
                applicant: applicant,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with gradient background
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade300,
                      Colors.blue.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.person, size: 30, color: Colors.white),
              ),
              const SizedBox(width: 16),
              
              // Applicant details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applicant['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Info with icons
                    Row(
                      children: [
                        Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${applicant['age']}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.work, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            applicant['occupation'],
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          applicant['timing'],
                          style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        if (applicant['gender'] != null && applicant['gender'].isNotEmpty)
                          Icon(
                            applicant['gender'] == 'Male' ? Icons.male : Icons.female,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        if (applicant['gender'] != null && applicant['gender'].isNotEmpty)
                          const SizedBox(width: 4),
                        if (applicant['gender'] != null && applicant['gender'].isNotEmpty)
                          Text(
                            applicant['gender'],
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                      ],
                    ),
                    
                    // Distance tag if available
                    if (distance != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place, size: 12, color: Colors.blue),
                              const SizedBox(width: 2),
                              Text(
                                '${distance.round()} m',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Arrow icon
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}