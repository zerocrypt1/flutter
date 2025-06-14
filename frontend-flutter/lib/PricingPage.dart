import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this dependency

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  _PricingPageState createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> with SingleTickerProviderStateMixin {
  int _selectedPlanIndex = 0;
  late Razorpay _razorpay;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  bool _isSubscriptionSuccess = false;

  // Environment variables
  String get razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? 'rzp_test_uCpWKWiRX50tVp';
  String get appName => dotenv.env['APP_NAME'] ?? 'My Applicants App';
  String get themeColor => dotenv.env['APP_THEME_COLOR'] ?? '#7C4DFF';
  String get defaultContact => dotenv.env['DEFAULT_CONTACT'] ?? '8416842051';
  String get defaultEmail => dotenv.env['DEFAULT_EMAIL'] ?? 'shivansh7940@gmail.com';
  String get currency => dotenv.env['CURRENCY'] ?? 'INR';
  bool get retryEnabled => dotenv.env['RETRY_ENABLED']?.toLowerCase() == 'true';
  int get retryMaxCount => int.tryParse(dotenv.env['RETRY_MAX_COUNT'] ?? '1') ?? 1;
  List<String> get externalWallets => dotenv.env['EXTERNAL_WALLETS']?.split(',') ?? ['paytm'];

  // Plan details with environment variables
  List<Map<String, dynamic>> get _plans => [
    {
      'name': 'Basic',
      'price': dotenv.env['BASIC_MONTHLY_PRICE'] ?? '349',
      'annualPrice': dotenv.env['BASIC_ANNUAL_PRICE'] ?? '2,989',
      'annualDiscount': dotenv.env['BASIC_ANNUAL_DISCOUNT'] ?? '1,200',
      'features': ['View all applicants', 'Basic filters', 'Email support'],
      'color': Color(int.tryParse(dotenv.env['BASIC_PLAN_COLOR'] ?? '0xFF4FC3F7') ?? 0xFF4FC3F7),
      'billingCycle': 'monthly',
      'bestValue': false,
    },
    {
      'name': 'Premium',
      'price': dotenv.env['PREMIUM_MONTHLY_PRICE'] ?? '699',
      'annualPrice': dotenv.env['PREMIUM_ANNUAL_PRICE'] ?? '5,988',
      'annualDiscount': dotenv.env['PREMIUM_ANNUAL_DISCOUNT'] ?? '3,400',
      'features': ['All basic features', 'Priority listing', 'Advanced filtering', 'Chat support'],
      'color': Color(int.tryParse(dotenv.env['PREMIUM_PLAN_COLOR'] ?? '0xFF7C4DFF') ?? 0xFF7C4DFF),
      'billingCycle': 'monthly',
      'bestValue': true,
    },
    {
      'name': 'Professional',
      'price': dotenv.env['PROFESSIONAL_MONTHLY_PRICE'] ?? '1,149',
      'annualPrice': dotenv.env['PROFESSIONAL_ANNUAL_PRICE'] ?? '9,999',
      'annualDiscount': dotenv.env['PROFESSIONAL_ANNUAL_DISCOUNT'] ?? '3,789',
      'features': ['All premium features', 'Background verification', 'Premium support', 'Analytics'],
      'color': Color(int.tryParse(dotenv.env['PROFESSIONAL_PLAN_COLOR'] ?? '0xFFFF9800') ?? 0xFFFF9800),
      'billingCycle': 'monthly',
      'bestValue': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  void _initializeRazorpay() {
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      
      debugPrint('Razorpay initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Razorpay: $e');
      Fluttertoast.showToast(
        msg: "Failed to initialize payment gateway: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    try {
      _razorpay.clear();
    } catch (e) {
      debugPrint('Error clearing Razorpay: $e');
    }
    _animationController.dispose();
    super.dispose();
  }

  void _openCheckout(String planName, String price) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      int pricePaise = int.parse(price.replaceAll(',', '')) * 100;

      var options = {
        'key': razorpayKeyId,
        'amount': pricePaise.toString(),
        'currency': currency,
        'name': appName,
        'description': '$planName Plan Subscription',
        'prefill': {
          'contact': defaultContact,
          'email': defaultEmail,
        },
        'external': {
          'wallets': externalWallets
        },
        'theme': {
          'color': themeColor,
        },
        'retry': {
          'enabled': retryEnabled,
          'max_count': retryMaxCount,
        },
      };
      
      debugPrint('Opening Razorpay checkout with options: $options');
      _razorpay.open(options);
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      debugPrint('Razorpay Error: $e');
      Fluttertoast.showToast(
        msg: "Error: Could not open payment gateway. Please try again. Details: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Payment Success: PaymentID: ${response.paymentId}");
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isSubscriptionSuccess = true;
      });
    }
    
    Fluttertoast.showToast(
      msg: "SUCCESS: Payment ID: ${response.paymentId}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
    
    _showSuccessDialog();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Payment Error: ${response.code} - ${response.message}");
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
    
    Fluttertoast.showToast(
      msg: "Payment failed: ${response.code} - ${response.message ?? 'Error occurred'}",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet: ${response.walletName}");
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
    
    Fluttertoast.showToast(
      msg: "EXTERNAL_WALLET: ${response.walletName}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 10),
              Text('Payment Successful!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thank you for subscribing to our service!'),
              SizedBox(height: 10),
              Text('You now have access to all applicants and features.'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Go to Home', style: TextStyle(fontSize: 16)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleBillingCycle(int planIndex) {
    setState(() {
      final plans = _plans;
      if (plans[planIndex]['billingCycle'] == 'monthly') {
        plans[planIndex]['billingCycle'] = 'annual';
      } else {
        plans[planIndex]['billingCycle'] = 'monthly';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Processing payment...', style: TextStyle(fontSize: 18)),
                ],
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.2),
                    Colors.white,
                  ],
                ),
              ),
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'Choose Your Plan',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Get full access to all applicants and features',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildFeatureComparison(),
                      const SizedBox(height: 20),
                      GridView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          return _buildPlanCard(index);
                        },
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 
                                         (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildRefundPolicy(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureComparison() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All plans include:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          _buildFeatureRow(Icons.search, 'Search and filter applicants'),
          _buildFeatureRow(Icons.location_on, 'Location-based applicant search'),
          _buildFeatureRow(Icons.notifications, 'Real-time notifications'),
          _buildFeatureRow(Icons.contact_page, 'Applicant detailed profiles'),
          _buildFeatureRow(Icons.support_agent, 'Customer support'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 22),
          SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundPolicy() {
    final refundDays = int.tryParse(dotenv.env['REFUND_DAYS'] ?? '7') ?? 7;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Money Back Guarantee',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We offer a $refundDays-day money-back guarantee if you\'re not satisfied with our service.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(int index) {
    final plan = _plans[index];
    final isMonthly = plan['billingCycle'] == 'monthly';
    final displayPrice = isMonthly ? plan['price'] : plan['annualPrice'];
    final displayPeriod = isMonthly ? '/month' : '/year';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedPlanIndex == index ? plan['color'] : Colors.grey[300]!,
          width: _selectedPlanIndex == index ? 2 : 1,
        ),
        boxShadow: _selectedPlanIndex == index
            ? [
                BoxShadow(
                  color: plan['color'].withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPlanIndex = index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plan['bestValue'])
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: plan['color'].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: plan['color'],
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              SizedBox(height: 8),
              Text(
                plan['name'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: plan['color'],
                ),
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    displayPrice,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                displayPeriod,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (isMonthly)
                InkWell(
                  onTap: () => _toggleBillingCycle(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 12, color: plan['color']),
                        SizedBox(width: 4),
                        Text(
                          'Annual billing',
                          style: TextStyle(
                            fontSize: 12,
                            color: plan['color'],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => _toggleBillingCycle(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Text(
                          'Save ₹${plan['annualDiscount']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Divider(height: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    plan['features'].length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: plan['color'],
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              plan['features'][i],
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _openCheckout(plan['name'], isMonthly ? plan['price'] : plan['annualPrice']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plan['color'],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: _selectedPlanIndex == index ? 4 : 0,
                  ),
                  child: const Text(
                    'Choose Plan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}