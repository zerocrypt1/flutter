import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import


class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> applicant;

  const ProfilePage({super.key, required this.applicant});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isFavorited = false;
  bool _isLoading = true;
  bool _isLoadingAction = false;
  Map<String, dynamic> _fullApplicantData = {};
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchFullApplicantData();
  }

  // Fetch complete applicant data from backend
  Future<void> _fetchFullApplicantData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First, fetch the applicant's complete data using the name to get the ID
      final applicantsResponse = await http.get(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/formdatas'),
      );

      if (applicantsResponse.statusCode == 200) {
        final List<dynamic> allApplicants = jsonDecode(applicantsResponse.body);
        
        // Find the applicant with matching name
        final matchingApplicant = allApplicants.firstWhere(
          (applicant) => applicant['name'] == widget.applicant['name'],
          orElse: () => null,
        );

        if (matchingApplicant != null) {
          // Store the full data and applicant ID
          setState(() {
            _fullApplicantData = matchingApplicant;
          });
          
          // Now check if this applicant is in the user's favorites
          await _checkIfFavorited(matchingApplicant['_id']);
        } else {
          throw Exception('Applicant not found');
        }
      } else {
        throw Exception('Failed to load applicant data');
      }
    } catch (e) {
      print("Error fetching applicant data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading applicant details')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIfFavorited(String applicantId) async {
    try {
      final token = await storage.read(key: 'authToken');
      final userId = await storage.read(key: 'userId');
      
      if (token == null || userId == null) {
        print("No auth token or user ID found");
        return;
      }
      
      final response = await http.get(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> favorites = data['favorites'] ?? [];
        
        setState(() {
          _isFavorited = favorites.contains(applicantId);
        });
      }
    } catch (e) {
      print("Error checking if favorited: $e");
    }
  }

  Future<void> _toggleFavorite() async {
    if (_fullApplicantData['_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot update favorites: Missing applicant ID')),
      );
      return;
    }

    setState(() {
      _isLoadingAction = true;
    });

    try {
      final token = await storage.read(key: 'authToken');
      final userId = await storage.read(key: 'userId');
      
      if (token == null || userId == null) {
        throw Exception('No authentication token or user ID found');
      }
      
      if (_isFavorited) {
        // Remove from favorites
        final response = await http.delete(
          Uri.parse('${dotenv.env['API_BASE_URL']}/api/users/$userId/favorites/${_fullApplicantData['_id']}'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        
        if (response.statusCode == 200) {
          setState(() {
            _isFavorited = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from favorites')),
          );
        } else {
          throw Exception('Failed to remove from favorites');
        }
      } else {
        // Add to favorites
        final response = await http.post(
          Uri.parse('${dotenv.env['API_BASE_URL']}/api/users/$userId/favorites'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'applicantId': _fullApplicantData['_id'],
          }),
        );
        
        if (response.statusCode == 200) {
          setState(() {
            _isFavorited = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to favorites')),
          );
        } else {
          throw Exception('Failed to add to favorites');
        }
      }
    } catch (e) {
      print("Error toggling favorite: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating favorites')),
      );
    } finally {
      setState(() {
        _isLoadingAction = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicantData = _isLoading ? widget.applicant : (_fullApplicantData.isNotEmpty ? _fullApplicantData : widget.applicant);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Soft background color
      appBar: AppBar(
        title: Text(
          'Applicant Profile', 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: Colors.grey[800],
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.2),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              icon: Icon(
                _isFavorited ? Icons.star : Icons.star_border,
                color: _isFavorited ? Colors.amber : Colors.grey[600],
                size: 24,
              ),
              onPressed: _fullApplicantData['_id'] == null || _isLoadingAction 
                  ? null 
                  : _toggleFavorite,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                )
                              ],
                              image: const DecorationImage(
                                image: NetworkImage('https://picsum.photos/200/200'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            applicantData['name'] ?? 'Name Unavailable',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Profile Details Section
                    _buildSectionTitle('Professional Information'),
                    _buildInfoCard([
                      _buildDetailRow('Occupation', applicantData['occupation'] ?? 'N/A'),
                      _buildDetailRow('Timing', 
                        _formatTimings(applicantData['timing'] ?? applicantData['timming'] ?? 'N/A')
                      ),
                      _buildDetailRow('Salary', applicantData['salary'] ?? 'N/A'),
                    ]),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Personal Details'),
                    _buildInfoCard([
                      _buildDetailRow('Gender', applicantData['gender'] ?? 'N/A'),
                      _buildDetailRow('Age', applicantData['age']?.toString() ?? 'N/A'),
                      _buildDetailRow('Phone', applicantData['phoneNumber'] ?? 'N/A'),
                    ]),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Contact Information'),
                    _buildInfoCard([
                      _buildDetailRow('Address', applicantData['address'] ?? 'N/A'),
                      _buildDetailRow('Landmarks', applicantData['landmarks'] ?? 'N/A'),
                      _buildDetailRow('State', applicantData['state'] ?? 'N/A'),
                    ]),

                    const SizedBox(height: 20),

                    _buildSectionTitle('Identification'),
                    _buildInfoCard([
                      _buildDetailRow('ID Proof', applicantData['identityProof'] ?? 'N/A'),
                    ]),
                  ],
                ),
              ),
            ),
    );
  }

  // Formatting timings to look more professional
  String _formatTimings(dynamic timings) {
    if (timings == null) return 'N/A';
    if (timings is String) return timings;
    if (timings is List) {
      return timings.join(', ');
    }
    return 'N/A';
  }

  // New method to create section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // New method to create info cards with a clean, professional look
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        children: children,
      ),
    );
  }

  // Improved detail row with more professional styling
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[900],
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}