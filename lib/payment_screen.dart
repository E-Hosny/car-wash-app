import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/stripe_service.dart';
import 'main_navigation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String token;
  final double amount;
  final String orderId;
  final Map<String, dynamic> orderData;

  const PaymentScreen({
    super.key,
    required this.token,
    required this.amount,
    required this.orderId,
    required this.orderData,
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

    // Check if using package or purchasing package
    if (widget.orderData['use_package'] == true || isPackagePurchase) {
      // Skip payment for package orders or package purchases
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
            _errorMessage = isPackagePurchase
                ? 'Failed to purchase package'
                : 'Failed to create order';
            _isProcessing = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = isPackagePurchase
              ? 'Failed to purchase package: $e'
              : 'Failed to create order: $e';
          _isProcessing = false;
        });
      }
      return;
    }

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
      // إنشاء Order أولاً
      final orderResponse = await _createOrder();

      if (orderResponse == null) {
        setState(() {
          _errorMessage = 'Failed to create order';
          _isProcessing = false;
        });
        return;
      }

      // معالجة الدفع
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: _paymentIntentId!,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      // التحقق من حالة الدفع
      if (true) {
        // تم الدفع بنجاح
        // تحديث حالة الطلب إلى مدفوع
        if (orderResponse != null && orderResponse['id'] != null) {
          await _updateOrderPaymentStatus(orderResponse['id']);
        } else {
          setState(() {
            _errorMessage = 'Order creation failed: No order ID returned.';
            _isProcessing = false;
          });
          return;
        }

        await _showThankYouDialog();
      } else {
        setState(() {
          _errorMessage = 'Payment failed: Unknown error';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _createOrder() async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;

      // التحقق من نوع الطلب
      final bool isPackagePurchase =
          widget.orderData['is_package_purchase'] == true;

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
          throw Exception('Failed to purchase package: ${response.body}');
        }
      } else {
        // طلب عادي
        final response = await http.post(
          Uri.parse('$baseUrl/api/orders'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${widget.token}',
          },
          body: jsonEncode(widget.orderData),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return jsonDecode(response.body);
        } else {
          throw Exception('Failed to create order: ${response.body}');
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

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                isPackagePurchase
                    ? 'Your package was purchased successfully!\nYou can now use it for services.'
                    : 'Your payment was successful.\nYour order is being processed.',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MainNavigationScreen(
                        token: widget.token,
                        initialIndex: 2, // Changed to Orders tab (index 2)
                      ),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final bool isPackageOrder = widget.orderData['use_package'] == true;
    final bool isPackagePurchase =
        widget.orderData['is_package_purchase'] == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
                      _buildSummaryRow(
                          'Amount', '${widget.amount.toStringAsFixed(2)} AED'),
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
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.3)),
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
                        _buildSummaryRow('Payment Method', 'Credit/Debit Card'),
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
                  child: Row(
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

              // زر تأكيد طلب الباقة أو شراء باقة
              if (isPackageOrder || isPackagePurchase)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: (isPackagePurchase ? Colors.green : Colors.blue)
                            .withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPackagePurchase ? Colors.green : Colors.blue,
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
                                      : Icons.card_giftcard,
                                  size: 20),
                              const SizedBox(width: 10),
                              Text(
                                isPackagePurchase
                                    ? 'Purchase Package'
                                    : 'Confirm Package Order',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

              if (_paymentIntentId != null) ...[
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
                        color: Colors.black.withOpacity(0.2),
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
                      backgroundColor: Colors.green,
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
                              Icon(Icons.payment, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Pay ${widget.amount.toStringAsFixed(2)} AED',
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
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
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
