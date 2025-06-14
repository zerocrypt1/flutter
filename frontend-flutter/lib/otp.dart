import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String tempToken;

  const OTPVerificationPage({
    Key? key,
    required this.email,
    required this.tempToken,
  }) : super(key: key);

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  late AnimationController _animationController;
  late Animation<double> _animation;
  String errorMessage = '';
  bool isLoading = false;
  bool isResending = false;
  int _remainingTime = 60; // 60 seconds countdown for resend
  Timer? _timer;
  final storage = FlutterSecureStorage();

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
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _resetTimer() {
    setState(() {
      _remainingTime = 60;
    });
    _timer?.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Handle OTP input field focus
  void _onOTPDigitChanged(String value, int index) {
    if (value.length == 1) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Verify when all digits are entered
        _verifyOTP();
      }
    }
  }

  Future<void> _verifyOTP() async {
    // Check if all fields are filled
    for (var controller in _controllers) {
      if (controller.text.isEmpty) {
        return;
      }
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    // Combine OTP digits
    final otp = _controllers.map((controller) => controller.text).join();
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5050/api/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'otp': otp,
          'tempToken': widget.tempToken,
        }),
      );

      // Check if the response has a body before trying to decode it
      if (response.body.isNotEmpty) {
        try {
          final responseData = jsonDecode(response.body);
          
          if (response.statusCode == 200) {
            final token = responseData['token'];
            final userId = responseData['userId'];

            // Store user credentials
            await storage.write(key: 'authToken', value: token);
            await storage.write(key: 'userId', value: userId.toString());

            // Navigate to home page and clear back stack
            Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
          } else {
            // Error response with valid JSON
            setState(() {
              errorMessage = responseData['msg'] ?? "Error: ${response.statusCode}";
            });
          }
        } catch (jsonError) {
          // JSON parsing error
          setState(() {
            errorMessage = "Error processing response: Invalid response format";
          });
        }
      } else {
        // Empty response body
        setState(() {
          errorMessage = "Server returned an empty response";
        });
      }
    } catch (error) {
      // Network or other errors
      setState(() {
        errorMessage = "Connection error: ${error.toString().split('\n')[0]}";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _resendOTP() async {
    if (_remainingTime > 0) return;

    setState(() {
      isResending = true;
      errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5050/api/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'tempToken': widget.tempToken,
        }),
      );

      if (response.body.isNotEmpty) {
        try {
          final responseData = jsonDecode(response.body);
          
          if (response.statusCode == 200) {
            setState(() {
              _resetTimer();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP has been resent to your email'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            setState(() {
              errorMessage = responseData['msg'] ?? "Failed to resend OTP";
            });
          }
        } catch (jsonError) {
          setState(() {
            errorMessage = "Error processing response: Invalid format";
          });
        }
      } else {
        setState(() {
          errorMessage = "Server returned an empty response";
        });
      }
    } catch (error) {
      setState(() {
        errorMessage = "Connection error: ${error.toString().split('\n')[0]}";
      });
    } finally {
      setState(() {
        isResending = false;
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
          'Verify Email',
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Email Verification Illustration
                    Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 60,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    Text(
                      'Email Verification',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                    ),
                    Text(
                      'We\'ve sent a verification code to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // OTP Input Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                        (index) => Container(
                          width: 45,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            onChanged: (value) => _onOTPDigitChanged(value, index),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            decoration: InputDecoration(
                              counter: const Offstage(),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                              ),
                            ),
                          ),
                        ),
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
                    
                    // Verification Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _verifyOTP,
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
                              'Verify Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Resend OTP Timer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Didn\'t receive the code? ',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        TextButton(
                          onPressed: _remainingTime == 0 && !isResending ? _resendOTP : null,
                          child: isResending
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                                  ),
                                )
                              : Text(
                                  _remainingTime > 0
                                      ? 'Resend in ${_remainingTime}s'
                                      : 'Resend OTP',
                                  style: TextStyle(
                                    color: _remainingTime > 0
                                        ? Colors.grey
                                        : Colors.deepPurple,
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