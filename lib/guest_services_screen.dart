import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login_screen.dart';
import 'services/language_service.dart';
import 'translations.dart';

class GuestServicesScreen extends StatefulWidget {
  const GuestServicesScreen({super.key});

  @override
  State<GuestServicesScreen> createState() => _GuestServicesScreenState();
}

class _GuestServicesScreenState extends State<GuestServicesScreen> {
  List services = [];
  bool isLoading = true;
  String? error;
  // Track expanded descriptions for each service
  Map<int, bool> expandedServices = {};
  String _currentLanguage = 'en';
  bool _isRTL = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    fetchServices();
  }

  Future<void> _loadLanguage() async {
    final lang = await LanguageService.getCurrentLanguage();
    final isRTL = await LanguageService.isRTL();
    if (mounted) {
      setState(() {
        _currentLanguage = lang;
        _isRTL = isRTL;
      });
    }
  }

  String _t(String key) {
    return AppTranslations.getTextWithFallback(key, _currentLanguage);
  }

  String _getCurrency() {
    return AppTranslations.getCurrency(_currentLanguage);
  }

  TextStyle _getArabicTextStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    if (_currentLanguage == 'ar') {
      return GoogleFonts.cairo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    } else {
      return GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
  }

  Future<void> fetchServices() async {
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

      // Get current language
      final currentLanguage = await LanguageService.getCurrentLanguage();
      
      final res = await http.get(
        Uri.parse('$baseUrl/api/services'),
        headers: {
          'Accept-Language': currentLanguage,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Handle both old format (List) and new format (Object with services and cache_version)
        List<dynamic> servicesList;
        if (data is Map && data.containsKey('services')) {
          // New format - object with services and cache_version
          servicesList = List<dynamic>.from(data['services'] ?? []);
        } else if (data is List) {
          // Old format - direct list
          servicesList = data;
        } else {
          servicesList = [];
        }
        setState(() {
          services = servicesList;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load services';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching services: $e');
      setState(() {
        error = 'Connection error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
              'You need to login to request services. Would you like to login now?'),
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: fetchServices,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : services.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_car_wash,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Services Available',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please check back later',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchServices,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          final price = double.tryParse(service['price'].toString()) ?? 0.0;
                          
                          return GestureDetector(
                            onTap: () {
                              // Add haptic feedback
                              HapticFeedback.selectionClick();
                              _showLoginPrompt();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.shade100,
                                    blurRadius: 6,
                                    offset: const Offset(0, 4),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Service Image - takes 25% of card width
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Builder(
                                          builder: (context) {
                                            final imageUrl = service['image_url'];
                                            if (imageUrl != null && imageUrl.toString().isNotEmpty) {
                                              return CachedNetworkImage(
                                                imageUrl: imageUrl.toString(),
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  color: Colors.grey.shade200,
                                                  child: Center(
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Colors.blue.shade300,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) {
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      color: Colors.grey.shade400,
                                                      size: 32,
                                                    ),
                                                  );
                                                },
                                              );
                                            } else {
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: Icon(
                                                  Icons.directions_car,
                                                  color: Colors.grey.shade400,
                                                  size: 40,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Service content - takes 75% of card width
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Service name and price
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  service['name'] ?? _t('services'),
                                                  style: _getArabicTextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Price badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                      color: Colors.green.shade300),
                                                ),
                                                child: Text(
                                                  '${price.toStringAsFixed(0)} ${_getCurrency()}',
                                                  style: _getArabicTextStyle(
                                                    color: Colors.green.shade700,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          // Service description with Read more/Show less
                                          if (service['description'] != null &&
                                              service['description'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  service['description'],
                                                  style: _getArabicTextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 13,
                                                    height: 1.3,
                                                  ),
                                                  maxLines: expandedServices[service['id']] == true ? null : 2,
                                                  overflow: expandedServices[service['id']] == true ? null : TextOverflow.ellipsis,
                                                ),
                                                // Show Read more/Show less button if description is long
                                                if (service['description'].toString().length > 100)
                                                  GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        expandedServices[service['id']] = !(expandedServices[service['id']] ?? false);
                                                      });
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        expandedServices[service['id']] == true 
                                                            ? (_currentLanguage == 'ar' ? 'عرض أقل' : 'Show less')
                                                            : (_currentLanguage == 'ar' ? 'اقرأ المزيد' : 'Read more'),
                                                        style: _getArabicTextStyle(
                                                          color: Colors.blue.shade600,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      ),
    );
  }
}
