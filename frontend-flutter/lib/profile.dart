import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      final applicantsResponse = await http.get(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/formdatas'),
      );

      if (applicantsResponse.statusCode == 200) {
        final List<dynamic> allApplicants = jsonDecode(applicantsResponse.body);
        
        final matchingApplicant = allApplicants.firstWhere(
          (applicant) => applicant['name'] == widget.applicant['name'],
          orElse: () => null,
        );

        if (matchingApplicant != null) {
          setState(() {
            _fullApplicantData = matchingApplicant;
          });
          
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Applicant Profile', 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            color: Colors.grey[800],
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[700], size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _isFavorited ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _isFavorited ? Icons.star : Icons.star_border,
                color: _isFavorited ? Colors.amber[600] : Colors.grey[600],
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 40 : 20, 
                  vertical: 20
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced Profile Header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: isTablet ? 160 : 140,
                            height: isTablet ? 160 : 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4F46E5).withOpacity(0.1),
                                  Color(0xFF7C3AED).withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF4F46E5).withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: const DecorationImage(
                                  image: NetworkImage('https://picsum.photos/200/200'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            applicantData['name'] ?? 'Name Unavailable',
                            style: TextStyle(
                              fontSize: isTablet ? 28 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[800],
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              applicantData['occupation'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Enhanced Timing Section
                    _buildSectionTitle('Availability Schedule', Icons.schedule),
                    _buildTimingCard(applicantData['timing'] ?? applicantData['timming'] ?? 'N/A'),
                    const SizedBox(height: 24),

                    // Professional Information Section
                    _buildSectionTitle('Professional Information', Icons.work),
                    _buildInfoCard([
                      _buildDetailRow('Occupation', applicantData['occupation'] ?? 'N/A', Icons.badge),
                    ]),
                    const SizedBox(height: 24),

                    // Personal Details Section
                    _buildSectionTitle('Personal Details', Icons.person),
                    _buildInfoCard([
                      _buildDetailRow('Gender', applicantData['gender'] ?? 'N/A', Icons.person_outline),
                      _buildDetailRow('Age', applicantData['age']?.toString() ?? 'N/A', Icons.cake),
                      _buildDetailRow('Phone', applicantData['phoneNumber'] ?? 'N/A', Icons.phone),
                    ]),
                    const SizedBox(height: 24),

                    // Location Information Section
                    _buildSectionTitle('Location Information', Icons.location_on),
                    _buildInfoCard([
                      _buildDetailRow('Address', applicantData['address'] ?? 'N/A', Icons.home),
                      _buildDetailRow('Landmarks', applicantData['landmarks'] ?? 'N/A', Icons.place),
                      _buildDetailRow('State', applicantData['state'] ?? 'N/A', Icons.map),
                    ]),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // Enhanced timing card with better UI
  Widget _buildTimingCard(dynamic timings) {
    List<String> timingList = [];
    
    if (timings is String && timings != 'N/A') {
      timingList = timings.split(',').map((e) => e.trim()).toList();
    } else if (timings is List) {
      timingList = timings.map((e) => e.toString()).toList();
    }

    if (timingList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Center(
          child: Text(
            'No availability schedule provided',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.access_time,
                  size: 20,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Available Times',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: timingList.map((timing) => _buildTimingChip(timing)).toList(),
          ),
        ],
      ),
    );
  }

  // Individual timing chip
  Widget _buildTimingChip(String timing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4F46E5).withOpacity(0.1),
            Color(0xFF7C3AED).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF4F46E5).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        timing,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4F46E5),
        ),
      ),
    );
  }

  // Enhanced section title with icon
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced info card with better styling
  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: children,
      ),
    );
  }

  // Enhanced detail row with icons and better styling
  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[900],
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}