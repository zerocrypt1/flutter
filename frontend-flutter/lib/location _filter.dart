import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationFilterPage extends StatefulWidget {
  final Function(double, double, int, String) onLocationSelected;
  final double? initialLatitude;
  final double? initialLongitude;
  final int initialRadius;
  final String? initialLandmark;

  const LocationFilterPage({
    super.key,
    required this.onLocationSelected,
    this.initialLatitude,
    this.initialLongitude,
    this.initialRadius = 5000, // Default to 5km
    this.initialLandmark,
  });

  @override
  _LocationFilterPageState createState() => _LocationFilterPageState();
}

class _LocationFilterPageState extends State<LocationFilterPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _customLandmarkController = TextEditingController();
  double? _latitude;
  double? _longitude;
  int _radius = 5000; // Default to 5km
  bool _isSearching = false;
  String _errorMessage = '';
  String _landmark = '';
  List<String> _nearbyLandmarks = [];
  // New variables to store landmark's coordinates
  Map<String, Map<String, double>> _landmarkCoordinates = {};
  bool _useCustomLandmark = false;
  bool _showLandmarkSection = true;
  List<Map<String, dynamic>> _recentSearches = [];
  final FocusNode _addressFocusNode = FocusNode();
  bool _filterApplied = false; // Track if filter is applied

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _radius = widget.initialRadius;
    _landmark = widget.initialLandmark ?? '';
    _landmarkController.text = _landmark;
    
    // If coordinates are provided, fetch nearby landmarks
    if (_latitude != null && _longitude != null) {
      _fetchNearbyLandmarks();
      _fetchAddressFromCoordinates();
    }
    
    // Load recent searches (this would typically use shared preferences)
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _landmarkController.dispose();
    _customLandmarkController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _loadRecentSearches() {
    // In a real app, this would load from shared preferences
    // For now, we'll use dummy data
    _recentSearches = [
      {'name': 'Central Park', 'lat': 40.7812, 'lng': -73.9665},
      {'name': 'Downtown', 'lat': 40.7127, 'lng': -74.0059},
    ];
  }

  void _saveRecentSearch(String name, double lat, double lng) {
    if (name.isEmpty) return; // Don't save empty names

    // In a real app, this would save to shared preferences
    final newSearch = {'name': name, 'lat': lat, 'lng': lng};
    
    // Check if this location already exists in recent searches
    final exists = _recentSearches.any((element) => 
      element['name'] == name && 
      element['lat'] == lat && 
      element['lng'] == lng);
    
    if (!exists) {
      setState(() {
        _recentSearches.insert(0, newSearch);
        // Keep only the most recent 5 searches
        if (_recentSearches.length > 5) {
          _recentSearches.removeLast();
        }
      });
    }
  }

  Future<void> _searchLocation() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an address to search.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = '';
      _filterApplied = false; // Reset filter applied status
    });

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        setState(() {
          _errorMessage = 'No location found for the given address.';
          _latitude = null;
          _longitude = null;
          _nearbyLandmarks = [];
        });
      } else {
        final loc = locations.first;
        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
        });
        
        // Save to recent searches
        _saveRecentSearch(address, loc.latitude, loc.longitude);
        
        // Fetch nearby landmarks for the found location
        _fetchNearbyLandmarks();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error finding location: ${e.toString()}';
        _latitude = null;
        _longitude = null;
        _nearbyLandmarks = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isSearching = true;
      _errorMessage = '';
      _filterApplied = false; // Reset filter applied status
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permission permanently denied.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Update address field with reverse geocoded location
      _fetchAddressFromCoordinates();
      
      // Fetch nearby landmarks for the current position
      _fetchNearbyLandmarks();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  Future<void> _fetchAddressFromCoordinates() async {
    if (_latitude == null || _longitude == null) return;
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _latitude!, 
        _longitude!,
        localeIdentifier: 'en_US',
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address = '';
        
        if (place.name != null && place.name!.isNotEmpty) {
          address += place.name!;
        }
        
        if (place.street != null && place.street!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.street!;
        }
        
        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.locality!;
        }
        
        if (place.country != null && place.country!.isNotEmpty) {
          if (address.isNotEmpty) address += ', ';
          address += place.country!;
        }
        
        if (mounted) {
          setState(() {
            _addressController.text = address;
            // Save to recent searches
            if (address.isNotEmpty) {
              _saveRecentSearch(address, _latitude!, _longitude!);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      // Don't update state as this is a supplementary feature
    }
  }
  
  // Modified to store landmark coordinates with better error handling
  Future<void> _fetchNearbyLandmarks() async {
    if (_latitude == null || _longitude == null) return;
    
    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });
    
    try {
      // Get nearby notable places that could be landmarks
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _latitude!,
        _longitude!,
        localeIdentifier: 'en_US',
      );
      
      // Extract potential landmarks and their coordinates
      List<String> landmarks = [];
      Map<String, Map<String, double>> landmarkCoords = {};
      
      // First, store the main location as a fallback
      landmarkCoords['Current Location'] = {
        'latitude': _latitude!,
        'longitude': _longitude!
      };
      landmarks.add('Current Location');
      
      // Add an offset to each landmark to simulate different locations
      double offset = 0.001; // Approximately 100m
      int index = 0;
      
      for (var place in placemarks) {
        // Each landmark will get slightly different coordinates
        double latOffset = offset * (index % 3 - 1);  // -1, 0, or 1
        double lngOffset = offset * ((index ~/ 3) % 3 - 1); // -1, 0, or 1
        
        // Add name if it's a landmark
        if (place.name != null && place.name!.isNotEmpty) {
          landmarks.add(place.name!);
          landmarkCoords[place.name!] = {
            'latitude': _latitude! + latOffset,
            'longitude': _longitude! + lngOffset
          };
          index++;
        }
        
        // Add thoroughfare (street) as a landmark
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          landmarks.add(place.thoroughfare!);
          landmarkCoords[place.thoroughfare!] = {
            'latitude': _latitude! + latOffset + 0.0005,
            'longitude': _longitude! + lngOffset + 0.0005
          };
          index++;
        }
        
        // Add subLocality as a landmark
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          landmarks.add(place.subLocality!);
          landmarkCoords[place.subLocality!] = {
            'latitude': _latitude! + latOffset - 0.0005,
            'longitude': _longitude! + lngOffset - 0.0005
          };
          index++;
        }
        
        // Add locality as a landmark
        if (place.locality != null && place.locality!.isNotEmpty) {
          landmarks.add(place.locality!);
          landmarkCoords[place.locality!] = {
            'latitude': _latitude! + latOffset * 2,
            'longitude': _longitude! + lngOffset * 2
          };
          index++;
        }
        
        // Add points of interest if available
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          landmarks.add(place.administrativeArea!);
          landmarkCoords[place.administrativeArea!] = {
            'latitude': _latitude! + latOffset * 3,
            'longitude': _longitude! + lngOffset * 3
          };
          index++;
        }
      }
      
      // Remove duplicates and update the state
      final uniqueLandmarks = landmarks.toSet().toList();
      
      if (mounted) {
        setState(() {
          _nearbyLandmarks = uniqueLandmarks;
          _landmarkCoordinates = landmarkCoords;
          
          // If landmark is empty and we have nearby landmarks, use the first one
          if (_landmark.isEmpty && _nearbyLandmarks.isNotEmpty) {
            _landmark = _nearbyLandmarks.first;
            _landmarkController.text = _landmark;
          } else if (!_nearbyLandmarks.contains(_landmark) && _nearbyLandmarks.isNotEmpty) {
            // If selected landmark isn't in the new list, reset to first one
            _landmark = _nearbyLandmarks.first;
            _landmarkController.text = _landmark;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching nearby landmarks: $e');
      // Don't set error message here as this is a supplementary feature
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // Helper method to get coordinates for a landmark with improved null safety
  Map<String, double> _getLandmarkCoordinates(String landmark) {
    try {
      // If the landmark exists in our map, return its coordinates
      if (_landmarkCoordinates.containsKey(landmark)) {
        final coords = _landmarkCoordinates[landmark];
        if (coords != null && 
            coords.containsKey('latitude') && 
            coords.containsKey('longitude') &&
            coords['latitude'] != null &&
            coords['longitude'] != null) {
          return {
            'latitude': coords['latitude']!,
            'longitude': coords['longitude']!
          };
        }
      }
      
      // Fall back to the main location if landmark not found or coordinates are invalid
      if (_latitude != null && _longitude != null) {
        return {
          'latitude': _latitude!,
          'longitude': _longitude!
        };
      }
      
      // Final fallback with error - hopefully never reached
      throw Exception('Invalid landmark coordinates');
    } catch (e) {
      debugPrint('Error getting landmark information: $e');
      // Return the main coordinates as fallback
      return {
        'latitude': _latitude ?? 0.0,
        'longitude': _longitude ?? 0.0
      };
    }
  }

  void _updateLandmark(String landmark) {
    if (landmark.isEmpty) return;
    
    setState(() {
      _landmark = landmark;
      _landmarkController.text = landmark;
      _useCustomLandmark = false;
      _filterApplied = false; // Reset filter when landmark changes
    });
  }
  
  void _setCustomLandmark() {
    final customLandmark = _customLandmarkController.text.trim();
    if (customLandmark.isEmpty || _latitude == null || _longitude == null) return;
    
    setState(() {
      _landmark = customLandmark;
      _landmarkController.text = customLandmark;
      _useCustomLandmark = true;
      
      // For custom landmarks, create an entry in our coordinates map
      // with a slight offset from the main location
      _landmarkCoordinates[customLandmark] = {
        'latitude': _latitude! + 0.002,  // Approximately 200m north
        'longitude': _longitude! + 0.001  // Approximately 100m east
      };
      
      _filterApplied = false; // Reset filter when landmark changes
    });
  }
  
  void _useRecentSearch(Map<String, dynamic> search) {
    if (!search.containsKey('lat') || !search.containsKey('lng') || !search.containsKey('name')) {
      return;
    }
    
    setState(() {
      _latitude = search['lat'];
      _longitude = search['lng'];
      _addressController.text = search['name'];
      _filterApplied = false; // Reset filter applied status
      
      // Fetch landmarks for this location
      _fetchNearbyLandmarks();
    });
  }
  
  // Modified to use landmark coordinates with better error handling
  void _applyFilter() {
    if (_latitude == null || _longitude == null) {
      setState(() {
        _errorMessage = 'Please select a location first.';
      });
      return;
    }
    
    try {
      double searchLat;
      double searchLng;
      
      // If landmark is selected and not empty, use its coordinates
      if (_showLandmarkSection && _landmark.isNotEmpty) {
        final coords = _getLandmarkCoordinates(_landmark);
        searchLat = coords['latitude'] ?? _latitude!;
        searchLng = coords['longitude'] ?? _longitude!;
      } else {
        // Use the main location coordinates if no landmark is selected
        searchLat = _latitude!;
        searchLng = _longitude!;
      }
      
      // Call the callback function with the landmark's coordinates
      widget.onLocationSelected(searchLat, searchLng, _radius, _landmark);
      
      setState(() {
        _filterApplied = true;
        _errorMessage = ''; // Clear any previous errors
      });
      
      // Show a snackbar to confirm filter is applied
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_landmark.isNotEmpty 
            ? 'Searching for applications near $_landmark within ${(_radius / 1000).toStringAsFixed(1)} km'
            : 'Searching for applications within ${(_radius / 1000).toStringAsFixed(1)} km'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error applying filter: ${e.toString()}';
      });
    }
  }
  
  // Modified to use landmark coordinates with better error handling
  void _saveAndClose() {
    if (_latitude == null || _longitude == null) {
      setState(() {
        _errorMessage = 'Please select a location first.';
      });
      return;
    }
    
    try {
      double searchLat;
      double searchLng;
      
      // If landmark is selected and not empty, use its coordinates
      if (_showLandmarkSection && _landmark.isNotEmpty) {
        final coords = _getLandmarkCoordinates(_landmark);
        searchLat = coords['latitude'] ?? _latitude!;
        searchLng = coords['longitude'] ?? _longitude!;
      } else {
        // Use the main location coordinates if no landmark is selected
        searchLat = _latitude!;
        searchLng = _longitude!;
      }
      
      widget.onLocationSelected(searchLat, searchLng, _radius, _landmark);
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving location: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Filter'),
        actions: [
          TextButton(
            onPressed: (_latitude != null && _longitude != null)
                ? _saveAndClose
                : null,
            child: const Text(
              'Apply',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address search section with improved UI
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addressController,
                              focusNode: _addressFocusNode,
                              decoration: InputDecoration(
                                labelText: 'Enter address or location',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                hintText: 'Search for an area, street, or city',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _addressController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            _addressController.clear();
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onSubmitted: (_) => _searchLocation(),
                            ),
                          ),
                        ],
                      ),
                      
                      // Recent searches
                      if (_recentSearches.isNotEmpty && _addressFocusNode.hasFocus)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 4),
                                child: Text(
                                  'Recent Searches',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              ...List.generate(_recentSearches.length, (index) {
                                final search = _recentSearches[index];
                                return ListTile(
                                  leading: const Icon(Icons.history, size: 18),
                                  title: Text(search['name'] ?? 'Unknown location'),
                                  dense: true,
                                  onTap: () {
                                    _useRecentSearch(search);
                                    FocusScope.of(context).unfocus();
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Search button and current location button in a row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _searchLocation,
                        icon: const Icon(Icons.search),
                        label: const Text('Search Location'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Current Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Toggle landmark section
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Landmark Filter',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Switch(
                      value: _showLandmarkSection,
                      onChanged: (value) {
                        setState(() {
                          _showLandmarkSection = value;
                          _filterApplied = false; // Reset filter when toggling landmark section
                          if (!value) {
                            // Clear landmark if turning off
                            _landmark = '';
                            _landmarkController.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
                
                // Landmark section (conditionally visible)
                if (_showLandmarkSection) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _landmarkController,
                          decoration: InputDecoration(
                            labelText: 'Landmark',
                            hintText: 'e.g., Mall, Park, School',
                            border: const OutlineInputBorder(),
                            enabled: false,
                            suffixIcon: _landmark.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _landmark = '';
                                        _landmarkController.clear();
                                        _filterApplied = false; // Reset filter when clearing landmark
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Custom landmark input
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customLandmarkController,
                          decoration: const InputDecoration(
                            labelText: 'Add custom landmark',
                            border: OutlineInputBorder(),
                            hintText: 'Enter your own landmark',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _setCustomLandmark,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  
                  // Nearby landmarks section with improved UI
                  if (_nearbyLandmarks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Nearby Landmarks:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _nearbyLandmarks.map((landmark) {
                          return FilterChip(
                            label: Text(landmark),
                            selected: _landmark == landmark,
                            onSelected: (selected) {
                              if (selected) {
                                _updateLandmark(landmark);
                              }
                            },
                            backgroundColor: Colors.white,
                            selectedColor: Colors.blue.shade100,
                            labelStyle: TextStyle(
                              color: _landmark == landmark ? Colors.blue.shade800 : Colors.black87,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: _landmark == landmark ? Colors.blue.shade400 : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
                
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_errorMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Search radius slider with improved UI
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Search Radius:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(_radius / 1000).toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.blue.shade400,
                          inactiveTrackColor: Colors.blue.shade100,
                          thumbColor: Colors.blue.shade700,
                          overlayColor: Colors.blue.shade200.withOpacity(0.3),
                          valueIndicatorColor: Colors.blue.shade700,
                          valueIndicatorTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Slider(
                          value: _radius.toDouble(),
                          min: 500,
                          max: 10000,
                          divisions: 19,
                          label: '${(_radius / 1000).toStringAsFixed(1)} km',
                          onChanged: (value) {
                            setState(() {
                              _radius = value.round();
                              _filterApplied = false; // Reset filter status when radius changes
                            });
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0.5 km', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('10 km', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Quick radius selection buttons
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRadiusButton('1 km', 1000),
                    _buildRadiusButton('3 km', 3000),
                    _buildRadiusButton('5 km', 5000),
                    _buildRadiusButton('10 km', 10000),
                  ],
                ),
                
                // Selected location information with improved UI
                const SizedBox(height: 24),
                if (_latitude != null && _longitude != null)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text(
                                'Selected Location:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow('Address:', _addressController.text),
                                    const SizedBox(height: 4),
                                    _buildInfoRow('Latitude:', _latitude!.toStringAsFixed(6)),
                                    const SizedBox(height: 4),
                                    _buildInfoRow('Longitude:', _longitude!.toStringAsFixed(6)),
                                    const SizedBox(height: 4),
                                    _buildInfoRow('Search Radius:', '$_radius meters (${(_radius / 1000).toStringAsFixed(1)} km)'),
                                    if (_landmark.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      _buildInfoRow('Landmark:', _landmark,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // NEW: Search results status indicator
                          if (_filterApplied) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Filter applied! Showing applicants within ${(_radius / 1000).toStringAsFixed(1)} km.',
                                      style: TextStyle(color: Colors.green.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                
                // NEW: Search Now button (prominent and separate from Apply button)
                const SizedBox(height: 24),
                if (_latitude != null && _longitude != null)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _applyFilter,
                          icon: const Icon(Icons.search),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Colors.orange,
                          ),
                          label: Text(
                            _filterApplied ? 'Search Again' : 'Search Nearby Applicants',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Apply button for saving and closing
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveAndClose,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          child: const Text(
                            'Save and Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRadiusButton(String label, int radiusValue) {
    final isSelected = _radius == radiusValue;
    return InkWell(
      onTap: () {
        setState(() {
          _radius = radiusValue;
          _filterApplied = false; // Reset filter status when radius changes
        });
      },
     
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue.shade800 : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {TextStyle? style}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: style ?? const TextStyle(),
          ),
        ),
      ],
    );
  }
}