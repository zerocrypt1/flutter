import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'otp.dart'; // Import the OTP verification page

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final storage = FlutterSecureStorage();
  late AnimationController _animationController;
  late Animation<double> _animation;
  String errorMessage = '';
  String successMessage = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegExp.hasMatch(email);
  }

  Future<void> _sendOTP() async {
    final email = emailController.text.trim();
    
    // Validate email
    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email address';
        successMessage = '';
      });
      return;
    }
    
    if (!_isValidEmail(email)) {
      setState(() {
        errorMessage = 'Please enter a valid email address';
        successMessage = '';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5050/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      // Check response content type to ensure it's JSON
      String? contentType = response.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        setState(() {
          errorMessage = 'Server returned an invalid response format. Please try again later.';
        });
        return;
      }

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          final tempToken = responseData['tempToken'];
          
          if (tempToken != null) {
            setState(() {
              successMessage = 'OTP sent successfully to your email!';
            });
            
            // Navigate to OTP verification page
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationPage(
                  email: email,
                  tempToken: tempToken,
                ),
              ),
            );
          } else {
            setState(() {
              errorMessage = 'Invalid server response. Missing token.';
            });
          }
        } catch (jsonError) {
          setState(() {
            errorMessage = 'Error processing server response: $jsonError';
          });
        }
      } else {
        // Handle error responses
        try {
          final errorData = jsonDecode(response.body);
          setState(() {
            errorMessage = errorData['msg'] ?? 'Error ${response.statusCode}: Failed to send OTP.';
          });
        } catch (jsonError) {
          setState(() {
            errorMessage = 'Error ${response.statusCode}: Failed to send OTP.';
          });
        }
      }
    } catch (error) {
      // For network and other errors
      setState(() {
        if (error.toString().contains('XMLHttpRequest error') || 
            error.toString().contains('<!DOCTYPE')) {
          errorMessage = 'Cannot connect to server. Please check your connection and try again.';
        } else {
          errorMessage = 'Connection error: ${error.toString().split('\n')[0]}';
        }
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
        title: const Text(
          'Forgot Password',
          style: TextStyle(color: Colors.deepPurple),
        ),
      ),
      body: FadeTransition(
        opacity: _animation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Forgot Password Illustration
                    Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        size: 60,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    Text(
                      'Password Reset',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Enter your email address and we\'ll send you a verification code to reset your password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Email Input
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.deepPurple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error Message
                    if (errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Success Message
                    if (successMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                successMessage,
                                style: TextStyle(color: Colors.green.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Submit Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'Send Reset Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Back to Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Remember your password? ',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Log In',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}