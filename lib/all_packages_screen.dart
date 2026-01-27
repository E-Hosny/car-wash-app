import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'payment_screen.dart';
import 'login_screen.dart';
import 'single_wash_order_screen.dart';

class AllPackagesScreen extends StatefulWidget {
  final String? token; // Made nullable for guest mode
  final bool isGuest;

  const AllPackagesScreen({super.key, this.token, this.isGuest = false});

  @override
  State<AllPackagesScreen> createState() => _AllPackagesScreenState();
}

class _AllPackagesScreenState extends State<AllPackagesScreen> {
  List<dynamic> packages = [];
  Map<String, dynamic>? userPackage;
  Map<String, dynamic>? currentPackage;
  bool canUpgrade = false;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchPackages();
    fetchUserPackage();
  }

  Future<void> fetchPackages() async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        setState(() {
          error =
              'Configuration error: BASE_URL not found. Please check your .env file.';
          isLoading = false;
        });
        return;
      }

      final headers = widget.isGuest
          ? <String, String>{}
          : {'Authorization': 'Bearer ${widget.token}'};

      final res = await http.get(
        Uri.parse('$baseUrl/api/packages'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final packagesList = data['data'] ?? [];
        final currentPackageData = data['current_package'];
        
        // Log package data for debugging
        print('📦 Fetched ${packagesList.length} packages');
        for (var package in packagesList) {
          print('📦 Package: ${package['name'] ?? 'Unknown'}');
          print('   - image: ${package['image']}');
          print('   - image_url: ${package['image_url']}');
          print('   - All keys: ${package.keys.toList()}');
        }
        
        setState(() {
          packages = packagesList;
          currentPackage = currentPackageData != null 
              ? Map<String, dynamic>.from(currentPackageData) 
              : null;
          canUpgrade = currentPackageData?['can_upgrade'] ?? false;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load packages';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching packages: $e');
      setState(() {
        error = 'Connection error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserPackage() async {
    if (widget.isGuest || widget.token == null) return; // Skip for guest users

    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/packages/my/current'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            userPackage = data['data'];
            canUpgrade = data['data']?['can_upgrade'] ?? false;
          });
        }
      }
    } catch (e) {
      // Handle error silently
      print('Error fetching user package: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Available Packages',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchPackages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              : packages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.card_giftcard_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No packages available',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // Packages List
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final package = packages[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildPackageCard(package),
                                );
                              },
                              childCount: packages.length,
                            ),
                          ),
                        ),
                        // Services section for current package
                        if (userPackage != null && 
                            userPackage!['services'] != null && 
                            (userPackage!['services'] as List).isNotEmpty)
                          SliverToBoxAdapter(
                            child: _buildCurrentPackageServicesSection(),
                          ),
                      ],
                    ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    // Check if this is the user's current package
    final isCurrentPackage =
        (userPackage != null && userPackage!['package']['id'] == package['id']) ||
        (currentPackage != null && currentPackage!['id'] == package['id']);

    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isCurrentPackage ? Colors.green : Colors.grey.shade200,
          width: isCurrentPackage ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صورة الباقة
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(18)),
                  child: SizedBox(
                    width: 140,
                    child: _buildPackageImage(package),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              package['name'] ?? 'Premium Package',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Display headers only
                            if (_hasDescriptionHeaders(package)) ...[
                              const SizedBox(height: 6),
                              ..._buildDescriptionHeaders(package),
                              const SizedBox(height: 0),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _showPackageDetailsDialog(package),
                                  icon: Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
                                  label: Text(
                                    'See Details',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                    minimumSize: const Size(0, 20),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 0),
                            ] else if (package['description'] != null && package['description'].toString().isNotEmpty) ...[
                              // Fallback for old string format
                              const SizedBox(height: 4),
                              Text(
                                package['description'].toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${package['price']} AED',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 0),
                                Text(
                                  'Valid for 1 month',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 0),
                              ],
                            ),
                          ),
                          const SizedBox(height: 0),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                              onPressed: isCurrentPackage && !canUpgrade
                                  ? null
                                  : widget.isGuest
                                      ? () => _showLoginPrompt()
                                      : () => _showPurchaseDialog(package),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCurrentPackage && !canUpgrade
                                    ? Colors.green
                                    : isCurrentPackage && canUpgrade
                                        ? Colors.orange
                                        : Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                minimumSize: const Size(0, 28),
                                elevation: 0,
                              ),
                              child: isCurrentPackage && !canUpgrade
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Your Package',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.1,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    )
                                  : isCurrentPackage && canUpgrade
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.upgrade,
                                                color: Colors.white, size: 16),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Upgrade',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 1.1,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'Buy',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentPackage)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Current Package',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(Map<String, dynamic> package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        title: Text(
          'Purchase Package',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (package['image'] != null || package['image_url'] != null)
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildPackageImage(package),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                package['name'] ?? 'Premium Package',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Show only description headers (not full description)
              if (package['description_headers'] != null && 
                  package['description_headers'] is List &&
                  (package['description_headers'] as List).isNotEmpty) ...[
                ...((package['description_headers'] as List).map((header) {
                  if (header == null || header.toString().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      header.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList()),
              ] else if (package['description'] != null && package['description'] is List) ...[
                // Fallback: Extract headers from description list if description_headers not available
                ...((package['description'] as List).map((item) {
                  if (item is Map && item['header'] != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        item['header']?.toString() ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }).toList()),
              ],
              const SizedBox(height: 16),
              // Price only
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Price',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      '${package['price']} AED',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              // Services list if available
              if (package['services'] != null && (package['services'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Services Included:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                ...(package['services'] as List).map((service) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${service['name'] ?? ''} × ${service['quantity'] ?? 0}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchasePackage(package);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Buy Now',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
              'You need to login to purchase packages. Would you like to login now?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Login'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _purchasePackage(Map<String, dynamic> package) async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Configuration error: BASE_URL not found. Please check your .env file.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // التحقق من صحة السعر
      final price = package['price'];
      if (price == null) {
        throw Exception('Package price is missing');
      }

      final priceValue = double.tryParse(price.toString());
      if (priceValue == null) {
        throw Exception('Invalid package price: $price');
      }

      // إنشاء معرف فريد للطلب
      final orderId = 'package_${package['id']}_${DateTime.now().millisecondsSinceEpoch}';

      // إنشاء payment intent أولاً
      final paymentResponse = await http.post(
        Uri.parse('$baseUrl/api/payments/create-intent'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': priceValue, // لا تحويل إلى سنتات، API يتعامل مع المبلغ مباشرة
          'currency': 'aed',
          'order_id': orderId,
          'is_package_purchase': true, // إضافة هذا لتحديد أن هذا شراء باقة
        }),
      );

      if (paymentResponse.statusCode != 200) {
        throw Exception(
            'Failed to create payment intent: ${paymentResponse.body}');
      }

      final paymentData = jsonDecode(paymentResponse.body);
      final paymentIntentId = paymentData['client_secret'];

      // الانتقال إلى شاشة الدفع
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            token: widget.token!,
            amount: priceValue,
            orderId: orderId,
            orderData: {
              'package_id': package['id'],
              'payment_intent_id': paymentIntentId,
              'is_package_purchase': true,
              'order_id': orderId,
            },
          ),
        ),
      );
    } catch (e) {
      print('Error purchasing package: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error creating payment: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCurrentPackageServicesSection() {
    final services = userPackage!['services'] as List;
    
    // Parse expiration date
    DateTime? expiresDate;
    String? expiresAtString;
    if (userPackage!['expires_at'] != null) {
      try {
        expiresAtString = userPackage!['expires_at'].toString();
        expiresDate = DateTime.parse(expiresAtString);
      } catch (e) {
        print('Error parsing expiration date: $e');
      }
    }
    
    // Calculate days remaining
    int? daysRemaining;
    if (expiresDate != null) {
      final now = DateTime.now();
      final difference = expiresDate.difference(now);
      daysRemaining = difference.inDays;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Current Package Services',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                // Expiration Date Info
                if (expiresDate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expiration Date',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _formatExpirationDate(expiresDate),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (daysRemaining != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: daysRemaining <= 7
                                            ? Colors.orange.shade700
                                            : Colors.white.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        daysRemaining > 0
                                            ? '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left'
                                            : 'Expired',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Services list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...services.map((service) {
            final remaining = service['remaining_quantity'] ?? 0;
            final total = service['total_quantity'] ?? 0;
            final percentage = total > 0 ? (remaining / total) : 0.0;
            final isAvailable = remaining > 0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAvailable ? Colors.green.shade200 : Colors.red.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.cancel,
                        color: isAvailable ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          service['name'] ?? 'Service',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$remaining / $total',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(percentage * 100).toInt()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAvailable
                        ? '$remaining remaining out of $total'
                        : 'Quantity exhausted',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  // Request Service Button
                  if (isAvailable) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _requestService(service),
                        icon: Icon(Icons.add_shopping_cart, size: 16),
                        label: Text(
                          'Request Service',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
                // Upgrade Button
                if (canUpgrade) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Scroll to packages section
                        // The upgrade button on package card will handle the purchase
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please select a package to upgrade',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: Icon(Icons.upgrade, size: 20),
                      label: Text(
                        'Upgrade Package',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _requestService(Map<String, dynamic> service) {
    if (widget.isGuest || widget.token == null) {
      _showLoginPrompt();
      return;
    }

    // Get service ID from the service data
    // From API: service['id'] contains the service_id
    final serviceId = service['id'];
    if (serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Service ID not found',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to single wash order screen with package enabled
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SingleWashOrderScreen(
          token: widget.token!,
          initialUsePackage: true, // Enable package usage automatically
          preselectedServiceId: serviceId is int ? serviceId : int.tryParse(serviceId.toString()),
        ),
      ),
    );
  }

  Widget _buildPackageImage(Map<String, dynamic> package) {
    // Check for image_url first (full URL like services)
    String? imageUrl;
    if (package['image_url'] != null && package['image_url'].toString().isNotEmpty) {
      imageUrl = package['image_url'].toString();
      print('🖼️ Loading package image from image_url: $imageUrl');
    } else if (package['image'] != null && package['image'].toString().isNotEmpty) {
      // Build URL from image path
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      imageUrl = '$baseUrl/storage/${package['image']}';
      print('🖼️ Loading package image from image path: $imageUrl');
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
              ),
            ),
          ),
          errorWidget: (context, url, error) {
            print('❌ Error loading package image: $url');
            print('❌ Error details: $error');
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
              ),
              child: Center(
                child: Icon(
                  Icons.card_giftcard,
                  size: 50,
                  color: Colors.blue.shade400,
                ),
              ),
            );
          },
        ),
      );
    }

    // Placeholder if no image
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
      ),
      child: Center(
        child: Icon(
          Icons.card_giftcard,
          size: 50,
          color: Colors.blue.shade400,
        ),
      ),
    );
  }

  String _formatExpirationDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Check if package has description headers
  bool _hasDescriptionHeaders(Map<String, dynamic> package) {
    if (package['description_headers'] != null) {
      final headers = package['description_headers'];
      if (headers is List && headers.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  // Build description headers widgets
  List<Widget> _buildDescriptionHeaders(Map<String, dynamic> package) {
    final headers = package['description_headers'];
    if (headers == null || headers is! List || headers.isEmpty) {
      return [];
    }

    return headers.map<Widget>((header) {
      if (header == null || header.toString().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          header.toString(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          softWrap: true,
        ),
      );
    }).toList();
  }

  // Show package details dialog
  void _showPackageDetailsDialog(Map<String, dynamic> package) {
    final isCurrentPackage =
        (userPackage != null && userPackage!['package']['id'] == package['id']) ||
        (currentPackage != null && currentPackage!['id'] == package['id']);
    final description = package['description'];
    final descriptionHeaders = package['description_headers'];
    
    // Parse description
    List<Map<String, String>> descriptionItems = [];
    
    if (descriptionHeaders != null && descriptionHeaders is List && descriptionHeaders.isNotEmpty) {
      // New format: has headers, get full description
      if (description != null) {
        if (description is List) {
          // It's already a list
          for (var item in description) {
            if (item is Map) {
              descriptionItems.add({
                'header': item['header']?.toString() ?? '',
                'description': item['description']?.toString() ?? '',
              });
            }
          }
        } else if (description is String) {
          // Try to parse as JSON
          try {
            final decoded = jsonDecode(description);
            if (decoded is List) {
              for (var item in decoded) {
                if (item is Map) {
                  descriptionItems.add({
                    'header': item['header']?.toString() ?? '',
                    'description': item['description']?.toString() ?? '',
                  });
                }
              }
            }
          } catch (e) {
            // Not JSON, treat as plain string
            descriptionItems.add({
              'header': 'Description',
              'description': description,
            });
          }
        }
      }
    } else if (description != null && description.toString().isNotEmpty) {
      // Old format: plain string
      descriptionItems.add({
        'header': 'Description',
        'description': description.toString(),
      });
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        package['name'] ?? 'Package Details',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: descriptionItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No description available',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: descriptionItems.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['header'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['description'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              // Buy Now button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close details dialog first
                      if (widget.isGuest) {
                        _showLoginPrompt();
                      } else if (isCurrentPackage && !canUpgrade) {
                        // Already has this package, do nothing or show message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'You already have this package',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        _showPurchaseDialog(package);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPackage && !canUpgrade
                          ? Colors.green
                          : isCurrentPackage && canUpgrade
                              ? Colors.orange
                              : Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isCurrentPackage && !canUpgrade
                          ? 'Your Package'
                          : isCurrentPackage && canUpgrade
                              ? 'Upgrade'
                              : 'Buy Now',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
