import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import
import 'otp.dart';
import 'package:flutter_aakrit/config/app_config.dart';

// Initializing storage
final storage = FlutterSecureStorage();

// Initialize Google Sign-In with your client ID
// IMPORTANT: Replace this with your actual Google Client ID
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: kIsWeb ? AppConfig.googleWebClientId : null,
  scopes: [
    'email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ],
);

class SignInSignUpPage extends StatefulWidget {
  const SignInSignUpPage({super.key});

  @override
  _SignInSignUpPageState createState() => _SignInSignUpPageState();
}

class _SignInSignUpPageState extends State<SignInSignUpPage> with SingleTickerProviderStateMixin {
  bool isSignIn = true; // Toggle between sign in and sign up
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  String errorMessage = '';
  bool isLoading = false;
  bool isSuccess = false; // New flag to track success messages
  String successMessage = ''; // New variable to store success messages
  
  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.deepPurple.withOpacity(0.05),
                  Colors.white,
                ],
              ),
            ),
          ),
          
          // Main content
          FadeTransition(
            opacity: _animation,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20.0 : screenWidth * 0.1,
                  vertical: 20.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(height: screenHeight * 0.06),
                        
                        // App Logo or Icon
                        Hero(
                          tag: 'appLogo',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Toggle Buttons for Sign In / Sign Up with animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ToggleButtons(
                              borderRadius: BorderRadius.circular(16),
                              constraints: const BoxConstraints(minWidth: 120, minHeight: 45),
                              isSelected: [isSignIn, !isSignIn],
                              selectedColor: Colors.white,
                              fillColor: Colors.deepPurple,
                              color: Colors.grey.shade600,
                              onPressed: (index) {
                                setState(() {
                                  isSignIn = index == 0;
                                  errorMessage = '';
                                  successMessage = '';
                                  isSuccess = false;
                                  // Reset animation
                                  _animationController.reset();
                                  _animationController.forward();
                                });
                              },
                              children: const <Widget>[
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                                  child: Text("Sign In"),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                                  child: Text("Sign Up"),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Heading Text with animation
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            isSignIn ? "Welcome Back" : "Create Account",
                            key: ValueKey<bool>(isSignIn),
                            style: const TextStyle(
                              fontSize: 28, 
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Subtitle
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            isSignIn
                                ? "Fill out the information below to access your account."
                                : "Let's get started by filling out the form below.",
                            key: ValueKey<bool>(isSignIn),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Success Message
                        if (isSuccess)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      successMessage,
                                      style: TextStyle(color: Colors.green.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Form fields with animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          constraints: BoxConstraints(
                            maxHeight: !isSignIn ? 380 : 170,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Name Input (only for Sign Up)
                                if (!isSignIn) ...[
                                  _buildTextField(
                                    controller: _nameController,
                                    label: "Full Name",
                                    icon: Icons.person_outline,
                                    keyboardType: TextInputType.name,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _emailController,
                                    label: "Email Address",
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _addressController,
                                    label: "Address",
                                    icon: Icons.home_outlined,
                                    keyboardType: TextInputType.streetAddress,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Phone Number Input
                                _buildTextField(
                                  controller: _phoneController,
                                  label: "Phone Number",
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),

                                // Password Input
                                _buildTextField(
                                  controller: _passwordController,
                                  label: "Password",
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  isPasswordVisible: isPasswordVisible,
                                  onTogglePasswordVisibility: () {
                                    setState(() {
                                      isPasswordVisible = !isPasswordVisible;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Confirm Password Field (if Sign Up)
                                if (!isSignIn)
                                  _buildTextField(
                                    controller: _confirmPasswordController,
                                    label: "Confirm Password",
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    isPasswordVisible: isConfirmPasswordVisible,
                                    onTogglePasswordVisibility: () {
                                      setState(() {
                                        isConfirmPasswordVisible = !isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Error Message
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorMessage,
                                      style: TextStyle(color: Colors.red.shade900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Sign In / Sign Up Button
                        ElevatedButton(
                          onPressed: isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 2,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isSignIn ? "Sign In" : "Get Started",
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // Divider with text
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey.shade300,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Google Sign In button with local asset image
                        ElevatedButton.icon(
                          onPressed: _handleGoogleSignIn,
                          icon: Icon(
                            Icons.g_mobiledata,
                            color: Colors.blue,
                            size: 28,
                          ), // Using a built-in icon instead of remote image
                          label: Text(
                            isSignIn ? 'Sign in with Google' : 'Sign up with Google',
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            elevation: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Apple sign in
                        ElevatedButton.icon(
                          onPressed: () {
                            // Implement Apple Sign In later
                            setState(() {
                              errorMessage = "Apple Sign In will be implemented soon";
                            });
                          },
                          icon: const Icon(Icons.apple, color: Colors.black, size: 28),
                          label: Text(
                            isSignIn ? 'Sign in with Apple' : 'Sign up with Apple',
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            elevation: 1,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Forgot Password (only in Sign In mode)
                        if (isSignIn)
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            ),
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (isLoading)
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

  // Reusable text field builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePasswordVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: onTogglePasswordVisibility,
                )
              : null,
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.deepPurple),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        obscureText: isPassword && !isPasswordVisible,
        keyboardType: keyboardType,
      ),
    );
  }

  // Authentication Handler
  void _handleAuth() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
      isSuccess = false;
    });

    try {
      if (isSignIn) {
        // Handle Sign In
        if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
          setState(() {
            errorMessage = "Please enter both phone number and password";
            isLoading = false;
          });
          return;
        }
        await _signIn();
      } else {
        // Handle Sign Up
        if (_nameController.text.isEmpty ||
            _emailController.text.isEmpty ||
            _addressController.text.isEmpty ||
            _phoneController.text.isEmpty ||
            _passwordController.text.isEmpty ||
            _confirmPasswordController.text.isEmpty) {
          setState(() {
            errorMessage = "Please fill out all fields";
            isLoading = false;
          });
          return;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() {
            errorMessage = "Passwords do not match";
            isLoading = false;
          });
          return;
        }
        await _signUp();
      }
    } catch (e) {
      setState(() {
        errorMessage = "An unexpected error occurred. Please try again.";
        isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
      isSuccess = false;
    });

    try {
      // Check if Google Sign-In is properly configured
      if (kIsWeb && (_googleSignIn.clientId == null || _googleSignIn.clientId == 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com')) {
        setState(() {
          errorMessage = "Google Sign-In is not configured correctly. Please add your client ID.";
          isLoading = false;
        });
        return;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in flow
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Get authentication details from Google Sign In
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        setState(() {
          errorMessage = "Failed to get authentication tokens";
          isLoading = false;
        });
        return;
      }

      // Send the Google ID token to your backend
      await _signInWithGoogle(idToken, googleUser);
    } catch (error) {
      setState(() {
        errorMessage = "Google sign in failed: $error";
        isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle(String idToken, GoogleSignInAccount googleUser) async {
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/auth/google'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'idToken': idToken,
          'name': googleUser.displayName,
          'email': googleUser.email,
          // Phone and address will be collected or updated later if needed
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Check if email verification is required
        if (responseData.containsKey('emailVerificationRequired') && 
            responseData['emailVerificationRequired'] == true &&
            responseData.containsKey('tempToken')) {
          // Navigate to OTP verification page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: googleUser.email,
                tempToken: responseData['tempToken'],
              ),
            ),
          ).then((_) {
            // This code runs when returning from the OTP page
            setState(() {
              isSuccess = true;
              successMessage = "Email verified successfully! You can now sign in.";
              isSignIn = true; // Switch to sign in mode
            });
          });
        } else {
          // Normal flow - store token and navigate home
          final token = responseData['token'];
          final userId = responseData['userId'];

          // Store user credentials
          await storeUserCredentials(token, userId);
          
          print("Google login successful: ${response.body}");
          
          // Navigate to home
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          errorMessage = jsonDecode(response.body)['msg'] ?? "Google sign in failed";
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = "Failed to authenticate with server: $error";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/auth/signin'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'phone': _phoneController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check if email verification is required
        if (responseData.containsKey('emailVerificationRequired') && 
            responseData['emailVerificationRequired'] == true &&
            responseData.containsKey('tempToken') &&
            responseData.containsKey('email')) {
          
          // Navigate to OTP verification page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: responseData['email'],
                tempToken: responseData['tempToken'],
              ),
            ),
          ).then((_) {
            // This code runs when returning from the OTP page
            setState(() {
              isSuccess = true;
              successMessage = "Email verified successfully! You can now sign in.";
            });
          });
        } else {
          // Normal sign in flow
          final token = responseData['token'];
          final userId = responseData['userId'];

          // Storing credentials
          await storeUserCredentials(token, userId);

          print("Login successful: ${response.body}");

          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          errorMessage = jsonDecode(response.body)['msg'] ?? "Sign in failed";
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = "Sign in failed: $error";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _signUp() async {
    try {
      print("Attempting to sign up...");
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'email': _emailController.text,
          'address': _addressController.text,
          'phone': _phoneController.text,
          'password': _passwordController.text
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Check for tempToken in the response for OTP verification
        if (responseData.containsKey('tempToken')) {
          // Send verification email
          await _sendVerificationEmail(_emailController.text, responseData['tempToken']);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: _emailController.text,
                tempToken: responseData['tempToken'],
              ),
            ),
          ).then((_) {
            // This code runs when returning from the OTP page
            setState(() {
              isSuccess = true;
              successMessage = "Email verified successfully! You can now sign in.";
              isSignIn = true; // Switch to sign in mode
              _clearFields();
            });
          });
        } else {
          // Fallback to default flow if no tempToken
          setState(() {
            isSuccess = true;
            successMessage = "Sign up successful! Please log in.";
            isSignIn = true;
            _clearFields();
          });
        }
      } else {
        setState(() {
          errorMessage = jsonDecode(response.body)['msg'] ?? "Sign up failed";
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = "An error occurred: $error";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Send verification email
  Future<void> _sendVerificationEmail(String email, String tempToken) async {
    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/auth/send-verification-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'tempToken': tempToken,
        }),
      );

      if (response.statusCode != 200) {
        print("Failed to send verification email: ${response.body}");
      }
    } catch (error) {
      print("Error sending verification email: $error");
    }
  }

  void _clearFields() {
    _nameController.clear();
    _emailController.clear();
    _addressController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> storeUserCredentials(String token, String userId) async {
    await storage.write(key: 'authToken', value: token);
    await storage.write(key: 'userId', value: userId);
  }
}