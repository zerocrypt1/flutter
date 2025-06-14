import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import


class Response {
  final String orderId;

  Response({required this.orderId});

  factory Response.fromJson(Map<String, dynamic> json) {
    return Response(
      orderId: json['order_id'],
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final Razorpay _razorpay = Razorpay();
  var _orderId = '';  // Dynamically fetched order ID

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  Future<void> _openCheckout() async {
    try {
      final response = await fetchOrderIdFromYourServer();  // Fetch dynamic order ID from server
      _orderId = response.orderId;

      var options = {
        'key': "rzp_test_uCpWKWiRX50tVp", // Replace with your actual Razorpay Key ID
        'amount': '10000', // Amount in paise (e.g., 10000 for Rs. 100)
        'currency': 'INR',
        'name': 'Your Company Name',
        'description': 'Payment for your product/service',
        'order_id': _orderId,  // Use the dynamically fetched order ID
        'prefill': {
          'contact': '9876543210',
          'email': 'test@example.com',
        },
        'external': {
          'wallets': ['paytm', 'upi']
        }
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        debugPrint('Error opening Razorpay Checkout: $e');
        // Handle errors while opening the Razorpay checkout
      }
    } catch (e) {
      debugPrint('Error fetching order ID: $e');
      // Handle the error when fetching order ID from your server
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Handle successful payment
    debugPrint('Payment Successful: $response');
    // Update UI or navigate to success screen
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Handle payment failure
    debugPrint('Payment Failed: $response');
    // Update UI or display error message
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet selection
    debugPrint('External Wallet Selected: $response');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Page'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _openCheckout,
          child: const Text('Pay Now'),
        ),
      ),
    );
  }
}

Future<Response> fetchOrderIdFromYourServer() async {
  final url = Uri.parse('${dotenv.env['API_BASE_URL']}/api/payment/create-order');
  final response = await http.post(
    url,
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'amount': 10000, // Example: Amount in paise (Rs. 100)
    }),
  );

  if (response.statusCode == 200) {
    final responseData = jsonDecode(response.body);
    return Response.fromJson(responseData);
  } else {
    throw Exception('Failed to fetch order ID from server');
  }
}