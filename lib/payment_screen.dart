import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/stripe_service.dart';
import 'main_navigation_screen.dart';
import 'my_orders_screen.dart';
import 'screens/package_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String token;
  final double amount;
  final String orderId;
  final Map<String, dynamic> orderData;
  final bool isMultiCar;

  const PaymentScreen({
    super.key,
    required this.token,
    required this.amount,
    required this.orderId,
    required this.orderData,
    this.isMultiCar = false,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _paymentIntentId;
  String? _errorMessage;
  CardFieldInputDetails? _card;

  @override
  void initState() {
    super.initState();
    _initializeStripe();

    // استخدام payment intent الموجود من all_packages_screen
    final bool isPackagePurchase =
        widget.orderData['is_package_purchase'] == true;
    if (isPackagePurchase && widget.orderData['payment_intent_id'] != null) {
      setState(() {
        _paymentIntentId = widget.orderData['payment_intent_id'];
      });
    }
  }

  Future<void> _initializeStripe() async {
    try {
      Stripe.publishableKey = StripeService.getPublishableKey();
      await Stripe.instance.applySettings();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize payment system: $e';
      });
    }
  }

  Future<void> _createPaymentIntent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final paymentIntent = await StripeService.createPaymentIntent(
        amount: widget.amount,
        currency: 'aed',
        orderId: widget.orderId,
        token: widget.token,
      );

      setState(() {
        _paymentIntentId = paymentIntent['client_secret'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create payment: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _processPayment() async {
    final bool isPackagePurchase =
        widget.orderData['is_package_purchase'] == true;

    // Check if using package (not purchasing package) - no payment needed
    if (widget.orderData['use_package'] == true) {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      try {
        final orderResponse = await _createOrder();
        if (orderResponse != null) {
          await _showThankYouDialog();
        } else {
          setState(() {
            _errorMessage = 'Failed to create order';
            _isProcessing = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to create order: $e';
          _isProcessing = false;
        });
      }
      return;
    }

    // For payment orders, process payment FIRST
    if (_paymentIntentId == null) {
      setState(() {
        _errorMessage = 'Payment intent not created';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // معالجة الدفع أولاً
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: _paymentIntentId!,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      // تم الدفع بنجاح - الآن ننشئ الطلب
      final orderResponse = await _createOrder();

      if (orderResponse == null) {
        setState(() {
          _errorMessage = isPackagePurchase
              ? 'Payment successful but failed to create package purchase'
              : 'Payment successful but failed to create order';
          _isProcessing = false;
        });
        return;
      }

      // تحديث حالة الطلب إلى مدفوع (فقط للطلبات العادية)
      if (!isPackagePurchase && orderResponse['id'] != null) {
        await _updateOrderPaymentStatus(orderResponse['id']);
      }

      await _showThankYouDialog();
    } catch (e) {
      setState(() {
        // تحديد نوع الخطأ بناءً على المرحلة
        if (e.toString().contains('Payment successful but failed to create')) {
          _errorMessage = e.toString();
        } else {
          _errorMessage = isPackagePurchase
              ? 'Package purchase payment failed: $e'
              : 'Payment failed: $e';
        }
        _isProcessing = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _createOrder() async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      print('=== _createOrder Debug Start ===');
      print('BASE_URL: $baseUrl');
      print('Order Data Type: ${widget.orderData.runtimeType}');
      print('Order Data Keys: ${widget.orderData.keys.toList()}');
      print('Full Order Data: ${widget.orderData}');

      // التحقق من نوع الطلب
      final bool isPackagePurchase =
          widget.orderData['is_package_purchase'] == true;
      print('Is Package Purchase: $isPackagePurchase');
      print('Is Multi Car: ${widget.isMultiCar}');

      if (isPackagePurchase) {
        // شراء باقة
        final response = await http.post(
          Uri.parse(
              '$baseUrl/api/packages/${widget.orderData['package_id']}/purchase'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
          body: jsonEncode({
            'payment_intent_id': widget.orderData['payment_intent_id'],
            'paid_amount': widget.amount,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return jsonDecode(response.body);
        } else {
          // Try to parse error message from response
          try {
            final errorData = jsonDecode(response.body);
            final errorMessage =
                errorData['message'] ?? 'Failed to purchase package';
            throw Exception(errorMessage);
          } catch (parseError) {
            throw Exception('Failed to purchase package. Please try again.');
          }
        }
      } else {
        // طلب عادي أو متعدد السيارات
        final endpoint = widget.isMultiCar ? 'orders/multi-car' : 'orders';

        // Debug logging
        print('=== Payment Screen API Call Debug ===');
        print('Endpoint: $baseUrl/api/$endpoint');
        print('Is Multi Car: ${widget.isMultiCar}');
        print('Headers: {');
        print('  Content-Type: application/json');
        print('  Accept: application/json');
        print('  Authorization: Bearer ${widget.token.substring(0, 10)}...');
        print('}');
        print('Request Body (JSON): ${jsonEncode(widget.orderData)}');
        print('==========================================');

        final response = await http.post(
          Uri.parse('$baseUrl/api/$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
          body: jsonEncode(widget.orderData),
        );

        print('API Response Status: ${response.statusCode}');
        print('API Response Body: ${response.body}');
        print('========================');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          print('✅ Order created successfully!');
          print('Response Data: ${responseData}');
          print('Response Keys: ${responseData.keys.toList()}');
          return responseData;
        } else {
          print('❌ Order creation failed!');
          print('Status Code: ${response.statusCode}');
          print('Response Headers: ${response.headers}');
          print('Error Response Body: ${response.body}');
          print('Error Response Length: ${response.body.length}');

          // Try to parse error message from response
          try {
            final errorData = jsonDecode(response.body);
            print('Parsed Error Data: $errorData');
            print('Error Data Type: ${errorData.runtimeType}');
            print('Error Data Keys: ${errorData.keys.toList()}');

            final errorMessage =
                errorData['message'] ?? 'Failed to create order';
            final errors = errorData['errors'];

            print('Final Error Message: $errorMessage');
            if (errors != null) {
              print('Validation Errors: $errors');
            }

            throw Exception(errorMessage);
          } catch (parseError) {
            print('❌ Failed to parse error response');
            print('Parse Error: $parseError');
            print('Raw Response: ${response.body}');
            throw Exception(
                'Failed to create order. Server response: ${response.body}');
          }
        }
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  Future<void> _updateOrderPaymentStatus(int orderId) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      await http.post(
        Uri.parse('$baseUrl/api/orders/$orderId/payment-status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'payment_status': 'paid',
          'payment_intent_id': _paymentIntentId,
        }),
      );
    } catch (e) {
      print('Error updating payment status: $e');
    }
  }

  Future<void> _showThankYouDialog() async {
    final bool isPackagePurchase =
        widget.orderData['is_package_purchase'] == true;

    if (isPackagePurchase) {
      // للباقات، انتقل إلى شاشة التهنئة المخصصة
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PackageSuccessScreen(
            token: widget.token,
            packageData: widget.orderData,
          ),
        ),
      );
    } else {
      // للطلبات العادية، اعرض الحوار العادي
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.celebration, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Thank You!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your payment was successful.\nYour order is being processed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog

                    // Navigate to main screen with orders tab selected
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => MainNavigationScreen(
                          token: widget.token,
                          initialIndex: 1, // Start with orders tab
                          forceOrdersTab: true, // Force stay on orders tab
                        ),
                      ),
                      (route) => false, // Remove all previous routes
                    );
                  },
                  child: Text('View Orders',
                      style: GoogleFonts.poppins(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPackageOrder = widget.orderData['use_package'] == true;
    final bool isPackagePurchase =
        widget.orderData['is_package_purchase'] == true;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Handle the back button press manually
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () =>
                Navigator.pop(context, false), // Return false on back press
          ),
          title: Text(
            isPackagePurchase
                ? 'Package Purchase'
                : (isPackageOrder ? 'Package Order' : 'Payment'),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF5F5F7)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // شعار التطبيق
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // تفاصيل الطلب
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPackagePurchase
                            ? 'Package Summary'
                            : (isPackageOrder
                                ? 'Package Order Summary'
                                : 'Order Summary'),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (isPackagePurchase) ...[
                        _buildSummaryRow('Package ID', widget.orderId),
                        _buildSummaryRow('Amount',
                            '${widget.amount.toStringAsFixed(2)} AED'),
                        _buildSummaryRow('Payment Method', 'Credit/Debit Card'),
                      ] else ...[
                        _buildSummaryRow('Order ID', widget.orderId),
                        if (isPackageOrder) ...[
                          _buildSummaryRow('Payment Method', 'Package Points'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.card_giftcard, color: Colors.blue),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This order will be paid using your package points',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _buildSummaryRow('Amount',
                              '${widget.amount.toStringAsFixed(2)} AED'),
                          _buildSummaryRow(
                              'Payment Method', 'Credit/Debit Card'),
                        ],
                      ],
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.security, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Secure payment powered by Stripe',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // رسالة الخطأ
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, false);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('Try Again'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                if (_errorMessage != null) const SizedBox(height: 20),

                // أزرار الدفع
                if (!isPackageOrder &&
                    !isPackagePurchase &&
                    _paymentIntentId == null)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createPaymentIntent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Initialize Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                // زر تأكيد طلب الباقة (لا يحتاج دفع)
                if (isPackageOrder)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.card_giftcard, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Confirm Package Order',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                // حقل إدخال بيانات البطاقة وزر الدفع لشراء الباقات
                if (_paymentIntentId != null &&
                    (isPackagePurchase ||
                        (!isPackageOrder && !isPackagePurchase))) ...[
                  const SizedBox(height: 20),
                  // حقل إدخال بيانات البطاقة
                  CardField(
                    onCardChanged: (card) {
                      setState(() {
                        _card = card;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Card Details',
                    ),
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isPackagePurchase ? Colors.green : Colors.black)
                                  .withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: ElevatedButton(
                      onPressed: (_isProcessing || !(_card?.complete ?? false))
                          ? null
                          : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isPackagePurchase ? Colors.green : Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    isPackagePurchase
                                        ? Icons.shopping_cart
                                        : Icons.payment,
                                    size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  isPackagePurchase
                                      ? 'Purchase Package - ${widget.amount.toStringAsFixed(2)} AED'
                                      : 'Pay ${widget.amount.toStringAsFixed(2)} AED',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                // معلومات إضافية
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Payment Information',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '• Your payment is secured by Stripe\n• No card details are stored on our servers\n• You will receive a confirmation email\n• Payment is processed in real-time',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
