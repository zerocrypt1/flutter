import 'package:flutter/material.dart';
import 'package:flutter_aakrit/sign_in_sign_up_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // Text controllers for editable fields
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // User data fields
  String name = '';
  String email = '';
  String address = '';
  String phoneNumber = '';
  String age = '';
  String state = '';
  String landmarks = '';
  String identityProof = '';
  List<String> favoriteIds = []; // IDs of favorite applicants
  List<Map<String, dynamic>> favoriteApplicants = []; // Details of favorite applicants
  List<dynamic> timingPreferences = [];
  bool isLoading = true;
  bool isSaving = false;

  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final token = await storage.read(key: 'authToken');
      final userId = await storage.read(key: 'userId');
      
      if (token == null || userId == null) {
        // Handle the case where there is no authentication
        throw Exception('Not authenticated');
      }
      
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          name = data['name'] ?? 'No Name';
          email = data['email'] ?? 'No Email';
          address = data['address'] ?? '';
          phoneNumber = data['phoneNumber'] ?? '';
          age = data['age']?.toString() ?? '';
          state = data['state'] ?? '';
          landmarks = data['landmarks'] ?? '';
          identityProof = data['identityProof'] ?? '';
          
          // Update text controllers with fetched data
          _addressController.text = address;
          _phoneController.text = phoneNumber;
          
          // Handle favorites (ensure it's a List<String>)
          if (data['favorites'] != null) {
            // If favorites is already populated with full objects
            if (data['favorites'] is List && data['favorites'].isNotEmpty && data['favorites'][0] is Map) {
              favoriteApplicants = List<Map<String, dynamic>>.from(
                data['favorites'].map((favorite) => favorite as Map<String, dynamic>)
              );
              favoriteIds = favoriteApplicants.map((applicant) => applicant['_id'].toString()).toList();
            } else {
              // If favorites is just a list of IDs
              favoriteIds = List<String>.from(data['favorites'].map((id) => id.toString()));
              _fetchFavoriteApplicants();
            }
          }
          
          // Handle timing preferences 
          if (data['timming'] != null) {
            timingPreferences = data['timming'];
          } else if (data['timing'] != null) {
            timingPreferences = data['timing'];
          }
        });
        
        setState(() {
          isLoading = false;
        });
      } else {
        // Handle error response
        print('Failed to fetch user profile: ${response.statusCode} ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile. Please try again.')),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching user profile: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading profile. Please try again.')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchFavoriteApplicants() async {
    if (favoriteIds.isEmpty) return;

    try {
      final token = await storage.read(key: 'authToken');
      
      // Fetch all applicants
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/formdatas'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> allApplicants = jsonDecode(response.body);
        
        // Filter to get only favorites
        final List<Map<String, dynamic>> favorites = [];
        for (final applicant in allApplicants) {
          if (favoriteIds.contains(applicant['_id'])) {
            favorites.add(applicant);
          }
        }
        
        setState(() {
          favoriteApplicants = favorites;
        });
      } else {
        print('Failed to fetch applicants: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching favorite applicants: $error');
    }
  }

  Future<void> _saveProfile() async {
    try {
      setState(() {
        isSaving = true;
      });
      
      final token = await storage.read(key: 'authToken');
      final userId = await storage.read(key: 'userId');
      
      final response = await http.put(
        Uri.parse('http://localhost:5050/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'address': _addressController.text,
          'phoneNumber': _phoneController.text,
          // Keep other fields as they are
          'favorites': favoriteIds,
        }),
      );

      if (response.statusCode == 200) {
        // Update local state with the new values
        setState(() {
          address = _addressController.text;
          phoneNumber = _phoneController.text;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      } else {
        print("Error updating profile: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile. Please try again.')),
        );
      }
    } catch (error) {
      print("Error updating profile: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating profile. Please try again.')),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _toggleFavorite(String applicantId, String applicantName) async {
    try {
      final token = await storage.read(key: 'authToken');
      final userId = await storage.read(key: 'userId');

      // Determine if the applicant is already in the favorites
      bool isFavorite = favoriteIds.contains(applicantId);

      if (isFavorite) {
        // Remove from favorites
        final response = await http.delete(
          Uri.parse('http://localhost:5050/api/users/$userId/favorites/$applicantId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            favoriteIds.remove(applicantId);
            favoriteApplicants.removeWhere((applicant) => applicant['_id'] == applicantId);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed $applicantName from favorites')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove from favorites')),
          );
        }
      } else {
        // Add to favorites - shouldn't happen in this context, but handled for completeness
        final response = await http.post(
          Uri.parse('http://localhost:5050/api/users/$userId/favorites'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'applicantId': applicantId,
          }),
        );

        if (response.statusCode == 200) {
          await _fetchUserProfile(); // Refresh the entire profile to get updated favorites
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added $applicantName to favorites')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add to favorites')),
          );
        }
      }
    } catch (error) {
      print("Error updating favorite: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating favorites')),
      );
    }
  }

  Future<void> _logout() async {
    try {
      // Clear the secure storage
      await storage.deleteAll();
      
      // Navigate to sign in/sign up page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => SignInSignUpPage()),
        (Route<dynamic> route) => false, // Remove all previous routes
      );
    } catch (error) {
      print("Error during logout: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error logging out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('My Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 200,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage('https://picsum.photos/400/200'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -60,
                        left: 30,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.tealAccent.withOpacity(0.3),
                          child: const CircleAvatar(
                            radius: 55,
                            backgroundImage: NetworkImage('https://picsum.photos/200/300'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 70),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          email,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        if (age.isNotEmpty)
                          Text(
                            'Age: $age',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        if (identityProof.isNotEmpty)
                          Text(
                            'ID: $identityProof',
                            style: const TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Editable fields section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Address',
                            hintText: 'Enter your address',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter your phone number',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 15),
                        
                        // Non-editable fields display
                        if (state.isNotEmpty) 
                          _buildInfoCard('State', state),
                        if (landmarks.isNotEmpty)
                          _buildInfoCard('Landmarks', landmarks),
                        
                        const SizedBox(height: 20),
                        
                        // Save button
                        Center(
                          child: SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Timing preferences section
                  if (timingPreferences.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Timing Preferences',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: timingPreferences.map<Widget>((timing) {
                              return Chip(
                                label: Text(timing.toString()),
                                backgroundColor: Colors.blue.shade100,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  
                  // Favorites section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Favorite Applicants',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        favoriteApplicants.isEmpty
                            ? const Text('No favorites added yet.')
                            : Column(
                                children: favoriteApplicants.map((applicant) {
                                  return _buildFavoriteCard(applicant);
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Logout button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Center(
                      child: SizedBox(
                        width: 150,
                        child: ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> applicant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  applicant['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () => _toggleFavorite(
                  applicant['_id'],
                  applicant['name'] ?? 'this applicant',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (applicant['occupation'] != null)
            Text(
              'Occupation: ${_formatField(applicant['occupation'])}',
              style: const TextStyle(fontSize: 14),
            ),
          if (applicant['age'] != null)
            Text(
              'Age: ${applicant['age']}',
              style: const TextStyle(fontSize: 14),
            ),
          if (applicant['gender'] != null)
            Text(
              'Gender: ${applicant['gender']}',
              style: const TextStyle(fontSize: 14),
            ),
          if (applicant['phoneNumber'] != null)
            Text(
              'Phone: ${applicant['phoneNumber']}',
              style: const TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              // Navigate to applicant detail page (you'll need to implement this)
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => ProfilePage(applicant: applicant),
              //   ),
              // );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  String _formatField(dynamic value) {
    if (value == null) return 'N/A';
    if (value is List) return value.join(', ');
    return value.toString();
  }
}