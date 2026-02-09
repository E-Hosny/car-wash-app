import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_car_screen.dart';
import 'map_picker_with_search_screen.dart';
import 'payment_screen.dart';
import 'main_navigation_screen.dart';
import 'services/package_service.dart';
import 'services/cache_service.dart';
import 'widgets/order_summary_card.dart';
import 'services/language_service.dart';
import 'translations.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String token;
  final int? selectedCarId;
  final List selectedServices;
  final Map<String, dynamic>? selectedSavedAddress;
  final String? selectedAddress;
  final LatLng? selectedLocation;
  final DateTime? selectedDateTime;
  final double totalPrice;
  final bool usePackage;
  final Map<String, dynamic>? userPackage;
  final List<dynamic> availableServices;
  final List<dynamic> cars;
  final List<Map<String, dynamic>> savedAddresses;
  final List<dynamic> services;
  final DateTime selectedDate;

  const OrderConfirmationScreen({
    super.key,
    required this.token,
    required this.selectedCarId,
    required this.selectedServices,
    required this.selectedSavedAddress,
    required this.selectedAddress,
    required this.selectedLocation,
    required this.selectedDateTime,
    required this.totalPrice,
    required this.usePackage,
    required this.userPackage,
    required this.availableServices,
    required this.cars,
    required this.savedAddresses,
    required this.services,
    required this.selectedDate,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  int? selectedCarId;
  Map<String, dynamic>? selectedSavedAddress;
  String? selectedAddress;
  LatLng? selectedLocation;
  DateTime? selectedDateTime;
  double totalPrice = 0;
  bool usePackage = false;
  List<dynamic> cars = [];
  List<Map<String, dynamic>> savedAddresses = [];
  bool isLoadingAddresses = false;
  bool isSubmittingOrder = false;
  List<int> bookedHours = [];
  List<int> unavailableHours = [];
  bool isLoadingTimeSlots = false;
  DateTime selectedDate = DateTime.now();
  bool isChangingDate = false;

  String _currentLanguage = 'en';
  bool _isRTL = false;
  late StreamSubscription _languageSubscription;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _languageSubscription = LanguageService.languageStream.listen((_) async {
      await _loadLanguage();
    });
    selectedCarId = widget.selectedCarId;
    selectedSavedAddress = widget.selectedSavedAddress;
    selectedAddress = widget.selectedAddress;
    selectedLocation = widget.selectedLocation;
    selectedDateTime = widget.selectedDateTime;
    totalPrice = widget.totalPrice;
    usePackage = widget.usePackage;
    cars = widget.cars;
    savedAddresses = widget.savedAddresses;
    selectedDate = widget.selectedDate;
    _fetchBookedTimeSlots();
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

  @override
  void dispose() {
    _languageSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchBookedTimeSlots([DateTime? date]) async {
    final targetDate = date ?? selectedDate;
    
    setState(() => isLoadingTimeSlots = true);
    try {
      final cacheService = CacheService();
      // Always fetch from API without checking cache
      final timeSlotsData = await cacheService.getBookedTimeSlotsFromAPI(widget.token, targetDate);
      
      if (!mounted) return;
      setState(() {
        bookedHours = List<int>.from(timeSlotsData['booked_hours'] ?? []);
        unavailableHours = List<int>.from(timeSlotsData['unavailable_hours'] ?? []);
        isLoadingTimeSlots = false;
      });
    } catch (e) {
      print('❌ Error fetching booked time slots: $e');
      if (!mounted) return;
      setState(() {
        bookedHours = [];
        unavailableHours = [];
        isLoadingTimeSlots = false;
      });
    }
  }

  Future<void> _fetchUserCars() async {
    try {
      final cacheService = CacheService();
      final carsData = await cacheService.getCars(widget.token);
      
      if (!mounted) return;
      setState(() {
        cars = carsData;
      });
    } catch (e) {
      print('Error fetching user cars: $e');
    }
  }

  Future<void> _fetchSavedAddresses() async {
    if (!mounted) return;
    setState(() => isLoadingAddresses = true);
    try {
      final cacheService = CacheService();
      final addressesData = await cacheService.getAddresses(widget.token);
      
      if (!mounted) return;
      setState(() {
        savedAddresses = addressesData;
        isLoadingAddresses = false;
      });
    } catch (e) {
      print('Error fetching saved addresses: $e');
      if (!mounted) return;
      setState(() {
        savedAddresses = [];
        isLoadingAddresses = false;
      });
    }
  }

  int _calculateTotalPointsUsed() {
    if (!usePackage || widget.userPackage == null || widget.availableServices.isEmpty)
      return 0;

    int totalPoints = 0;
    for (var service in widget.selectedServices) {
      int serviceId;
      if (service is Map && service.containsKey('id')) {
        serviceId = service['id'] as int;
      } else if (service is int) {
        serviceId = service;
      } else {
        continue;
      }

      final remaining = PackageService.getRemainingQuantityForService(
        widget.availableServices,
        serviceId,
      );
      if (remaining > 0) {
        totalPoints += 1; // Each service uses 1 quantity
      }
    }
    return totalPoints;
  }

  String _formatSelectedTime(DateTime dateTime) {
    String period = dateTime.hour < 12 ? 'AM' : 'PM';
    int displayHour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    if (dateTime.hour == 12) displayHour = 12;

    String dateLabel = '';
    if (_isSameDate(dateTime, DateTime.now())) {
      dateLabel = _t('today');
    } else if (_isSameDate(dateTime, DateTime.now().add(const Duration(days: 1)))) {
      dateLabel = _t('tomorrow');
    } else if (_isSameDate(dateTime, DateTime.now().add(const Duration(days: 2)))) {
      dateLabel = _t('day_after');
    } else {
      dateLabel = '${dateTime.day}/${dateTime.month}';
    }

    return '$dateLabel - ${displayHour}:00 $period';
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _submitOrder() async {
    if (selectedCarId == null ||
        widget.selectedServices.isEmpty ||
        selectedSavedAddress == null ||
        selectedDateTime == null) {
      _showErrorDialog(
        'Missing Information',
        'Please select car, address, and time slot to continue.',
        Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() {
      isSubmittingOrder = true;
    });

    try {
      final orderData = {
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'address': selectedAddress ?? 'Selected from map',
        'street': selectedSavedAddress?['street'],
        'building': selectedSavedAddress?['building'],
        'floor': selectedSavedAddress?['floor'],
        'apartment': selectedSavedAddress?['apartment'],
        'car_id': selectedCarId,
        'services': widget.selectedServices,
        'scheduled_at': selectedDateTime?.toIso8601String(),
        'total': totalPrice,
        'use_package': usePackage,
      };

      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            token: widget.token,
            amount: totalPrice,
            orderId: orderId,
            orderData: orderData,
          ),
        ),
      );

      if (result == true) {
        // Invalidate orders cache to ensure fresh data
        final cacheService = CacheService();
        cacheService.invalidateOrders(widget.token);
        
        await _showOrderSuccessAnimation();
        _navigateToOrders();
      } else if (result == false) {
        _showErrorDialog(
          'Payment Failed',
          'Your order was not created due to payment failure. Please try again.',
          Icons.payment,
        );
      }
    } catch (e) {
      print('Error submitting order: $e');
      _showErrorDialog(
        'Order Error',
        'An error occurred while creating your order. Please try again.',
        Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmittingOrder = false;
        });
      }
    }
  }

  void _navigateToOrders() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainNavigationScreen(
          token: widget.token,
          initialIndex: 2,
          showPaymentSuccess: false,
        ),
      ),
    );
  }

  Future<void> _showOrderSuccessAnimation() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade200,
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: AlwaysStoppedAnimation(1.0),
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade200,
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Order Created Successfully!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context);
  }

  void _showErrorDialog(String title, String message, IconData icon) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade50,
                Colors.red.shade100,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: Text(
          _t('order_confirmation'),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F5F7)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable content
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: 80 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selected Car Section
                      _buildSelectedCarSection(),
                      const SizedBox(height: 16),

                      // Selected Address Section
                      _buildSelectedAddressSection(),
                      const SizedBox(height: 16),

                      // Schedule Section
                      _buildScheduleSection(),
                      const SizedBox(height: 16),

                      // Order Summary
                      OrderSummaryCard(
                        totalPrice: totalPrice,
                        usePackage: usePackage,
                        selectedServicesCount: widget.selectedServices.length,
                        remainingPoints: widget.userPackage?['remaining_points'],
                        totalPointsUsed: _calculateTotalPointsUsed(),
                        currency: _t('riyal'),
                        language: _currentLanguage,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Fixed Pay Now Button at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildFixedPaymentButton(),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSelectedCarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle(_t('selected_car')),
            if (selectedCarId != null)
              TextButton(
                onPressed: () {
                  _showCarSelectionDialog();
                },
                child: Text(
                  _t('change'),
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        if (selectedCarId == null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.directions_car, size: 36, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No cars available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('add_car_to_continue'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final added = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddCarScreen(token: widget.token),
                        ),
                      );
                      if (added == true) {
                        CacheService().invalidateCars(widget.token);
                        await _fetchUserCars();
                        if (cars.isNotEmpty) {
                          setState(() {
                            selectedCarId = cars.last['id'];
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(_t('add_car')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Builder(
            builder: (context) {
              final car = cars.firstWhere((c) => c['id'] == selectedCarId);
              return Card(
                color: Colors.green[50],
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                  title: Text(
                    '${car['brand']['name']} ${car['model']['name']}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Year: ${car['year']['year']} • Color: ${car['color']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      if (car['license_plate'] != null &&
                          car['license_plate'].toString().isNotEmpty)
                        Text(
                          'License Plate: ${car['license_plate']}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _showCarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _t('select_car'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: cars.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _t('no_cars_available'),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t('add_new_car_to_continue'),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: cars.length,
                        itemBuilder: (context, index) {
                          final car = cars[index];
                          final isSelected = selectedCarId == car['id'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedCarId = car['id'];
                                  });
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue.shade600
                                              : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.directions_car,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${car['brand']['name']} ${car['model']['name']}',
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isSelected
                                                    ? Colors.blue.shade900
                                                    : Colors.grey.shade900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_t('year')}: ${car['year']['year']} • ${_t('color')}: ${car['color']}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade600,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.grey.shade400,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Divider
              if (cars.isNotEmpty)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
              // Add New Car Button
              Container(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final added = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddCarScreen(token: widget.token),
                        ),
                      );
                      if (added == true) {
                        CacheService().invalidateCars(widget.token);
                        await _fetchUserCars();
                        if (cars.isNotEmpty) {
                          setState(() {
                            selectedCarId = cars.last['id'];
                          });
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _t('add_new_car'),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
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

  Widget _buildSelectedAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle(_t('selected_address')),
            TextButton(
              onPressed: () {
                _showAddressSelectionDialog();
              },
              child: Text(
                selectedSavedAddress == null ? _t('select') : _t('change'),
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (selectedSavedAddress == null) ...[
          Card(
            child: InkWell(
              onTap: () {
                _showAddressSelectionDialog();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Icon(Icons.location_off, size: 36, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No address selected',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap here to select or add an address',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          Card(
            color: Colors.green[50],
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: () {
                _showAddressSelectionDialog();
              },
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
              title: Text(
                selectedSavedAddress!['label'] ??
                    selectedSavedAddress!['address'] ??
                    'Address',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                '${selectedSavedAddress!['street'] ?? ''} ${selectedSavedAddress!['building'] ?? ''} ${selectedSavedAddress!['floor'] ?? ''} ${selectedSavedAddress!['apartment'] ?? ''}\n${selectedSavedAddress!['address'] ?? ''}',
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit, color: Colors.green, size: 20),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _addNewAddressDialog(LatLng latlng, String address) async {
    final labelController = TextEditingController();
    final streetController = TextEditingController();
    final buildingController = TextEditingController();
    final floorController = TextEditingController();
    final apartmentController = TextEditingController();
    final notesController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 20,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Address Details',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete your address information',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    label: RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          const TextSpan(text: 'Label'),
                          const TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    hintText: 'e.g. Home, Work',
                    prefixIcon: const Icon(Icons.label),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: streetController,
                  decoration: InputDecoration(
                    label: const Text('Street'),
                    hintText: 'Enter street name',
                    prefixIcon: const Icon(Icons.route),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: buildingController,
                  decoration: InputDecoration(
                    label: const Text('Building'),
                    hintText: 'Enter building name/number',
                    prefixIcon: const Icon(Icons.business),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    label: const Text('Notes'),
                    hintText: 'Additional instructions (optional)',
                    prefixIcon: const Icon(Icons.note),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.place, color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setState(() => isSaving = true);
                                try {
                                  final baseUrl = dotenv.env['BASE_URL'];
                                  if (baseUrl == null || baseUrl.isEmpty) {
                                    setState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Configuration error: BASE_URL not found'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  final res = await http.post(
                                    Uri.parse('$baseUrl/api/addresses'),
                                    headers: {
                                      'Authorization': 'Bearer ${widget.token}',
                                      'Content-Type': 'application/json',
                                    },
                                    body: jsonEncode({
                                      'label': labelController.text,
                                      'street': streetController.text,
                                      'building': buildingController.text,
                                      'floor': floorController.text,
                                      'apartment': apartmentController.text,
                                      'notes': notesController.text,
                                      'address': address,
                                      'latitude': latlng.latitude,
                                      'longitude': latlng.longitude,
                                    }),
                                  );
                                  setState(() => isSaving = false);
                                  if (res.statusCode == 201) {
                                    CacheService().invalidateAddresses(widget.token);
                                    await _fetchSavedAddresses();
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Address saved!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to save address'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving address: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save Address',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
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
    );
  }

  void _showAddressSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 20,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('select_address'),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t('choose_from_saved_addresses'),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: savedAddresses.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 20),
                            Text(
                              _t('no_saved_addresses'),
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: savedAddresses.length,
                        itemBuilder: (context, index) {
                          final address = savedAddresses[index];
                          final isSelected = selectedSavedAddress?['id'] == address['id'];
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedSavedAddress = address;
                                selectedAddress = address['address'];
                                selectedLocation = LatLng(
                                  double.parse(address['latitude'].toString()),
                                  double.parse(address['longitude'].toString()),
                                );
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 24,
                                    color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          address['label'] ?? 'Address',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: isSelected
                                                ? Colors.blue.shade800
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          address['address'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isSelected)
                                    Icon(Icons.check_circle, 
                                         color: Colors.blue.shade600, 
                                         size: 24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final picked = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapPickerWithSearchScreen(
                            initialLocation: selectedLocation ??
                                const LatLng(25.2048, 55.2708),
                            token: widget.token,
                          ),
                        ),
                      );
                      if (picked != null && picked is Map && picked['latlng'] != null) {
                        // Address will be saved in the dialog
                        await _fetchSavedAddresses();
                        if (savedAddresses.isNotEmpty) {
                          setState(() {
                            selectedSavedAddress = savedAddresses.last;
                            selectedAddress = savedAddresses.last['address'];
                            selectedLocation = LatLng(
                              double.parse(savedAddresses.last['latitude'].toString()),
                              double.parse(savedAddresses.last['longitude'].toString()),
                            );
                          });
                        }
                      }
                    } catch (e) {
                      print('Error opening map picker: $e');
                    }
                  },
                  icon: const Icon(Icons.add_location_alt, size: 22),
                  label: Text(
                    _t('add_new_address'),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_t('schedule')),
        const SizedBox(height: 12),
        // Date Selection
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _t('select_date'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildModernDateOptionInline(
                      _t('today'),
                      DateTime.now(),
                      Icons.today),
                  const SizedBox(height: 4),
                  _buildModernDateOptionInline(
                      _t('tomorrow'),
                      DateTime.now()
                          .add(const Duration(days: 1)),
                      Icons.event_available),
                  const SizedBox(height: 4),
                  _buildModernDateOptionInline(
                      _t('day_after'),
                      DateTime.now()
                          .add(const Duration(days: 2)),
                      Icons.date_range),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Time Slots
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time,
                    color: Colors.green.shade700, size: 18),
                const SizedBox(width: 6),
                Text(
                  _t('select_time'),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3.2,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _generateTimeSlots().length,
              itemBuilder: (context, index) {
                  final slot = _generateTimeSlots()[index];
                  final isSelected = selectedDateTime !=
                          null &&
                      selectedDateTime!.hour ==
                          slot['hour'] &&
                      _isSameDate(
                          selectedDateTime!, selectedDate);
                  final isBooked = slot['isBooked'] as bool;
                  final isUnavailable =
                      slot['isUnavailable'] as bool;
                  final isPastHour =
                      slot['isPastHour'] as bool;

                  return GestureDetector(
                    onTap: (isBooked ||
                            isUnavailable ||
                            isPastHour)
                        ? null
                        : () => _selectTimeSlotInline(slot),
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: isBooked
                            ? Colors.red.shade50
                            : isUnavailable
                                ? Colors.orange.shade50
                                : isPastHour
                                    ? Colors.grey.shade100
                                    : (isSelected
                                        ? Colors
                                            .green.shade600
                                        : Colors.white),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: isBooked
                              ? Colors.red.shade300
                              : isUnavailable
                                  ? Colors.orange.shade300
                                  : isPastHour
                                      ? Colors.grey.shade400
                                      : (isSelected
                                          ? Colors
                                              .green.shade600
                                          : Colors
                                              .grey.shade300),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      Colors.green.shade200,
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                  spreadRadius: 2,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.grey.shade100,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                slot['label'],
                                style: GoogleFonts.poppins(
                                  color: isBooked
                                      ? Colors.red.shade600
                                      : isUnavailable
                                          ? Colors
                                              .orange.shade600
                                          : isPastHour
                                              ? Colors.grey
                                                  .shade500
                                              : (isSelected
                                                  ? Colors
                                                      .white
                                                  : Colors
                                                      .grey
                                                      .shade800),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                            if (isBooked ||
                                isUnavailable ||
                                isPastHour) ...[
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  isPastHour ? _t('past') : _t('off'),
                                  style: GoogleFonts.poppins(
                                    color: isBooked
                                        ? Colors.red.shade600
                                        : isUnavailable
                                            ? Colors.orange
                                                .shade600
                                            : Colors.grey
                                                .shade500,
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
            ),
          ],
        ),
      ],
    );
  }

  void _showTimeSlotDialog() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Available Times...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Refresh booked time slots before showing dialog
    print('🔄 Refreshing booked time slots before showing dialog');
    await _fetchBookedTimeSlots();

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Colors.black,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _t('select_date_time'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close,
                            color: Colors.grey.shade600, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      children: [
                        // Date Selection
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      color: Colors.blue.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _t('select_date'),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Column(
                                children: [
                                  _buildModernDateOption(
                                      _t('today'),
                                      DateTime.now(),
                                      setDialogState,
                                      Icons.today),
                                  const SizedBox(height: 6),
                                  _buildModernDateOption(
                                      _t('tomorrow'),
                                      DateTime.now()
                                          .add(const Duration(days: 1)),
                                      setDialogState,
                                      Icons.event_available),
                                  const SizedBox(height: 6),
                                  _buildModernDateOption(
                                      _t('day_after'),
                                      DateTime.now()
                                          .add(const Duration(days: 2)),
                                      setDialogState,
                                      Icons.date_range),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Time Slots
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      color: Colors.green.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _t('select_time'),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 2.8,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: _generateTimeSlots().length,
                                  itemBuilder: (context, index) {
                                    final slot = _generateTimeSlots()[index];
                                    final isSelected = selectedDateTime !=
                                            null &&
                                        selectedDateTime!.hour ==
                                            slot['hour'] &&
                                        _isSameDate(
                                            selectedDateTime!, selectedDate);
                                    final isBooked = slot['isBooked'] as bool;
                                    final isUnavailable =
                                        slot['isUnavailable'] as bool;
                                    final isPastHour =
                                        slot['isPastHour'] as bool;

                                    return GestureDetector(
                                      onTap: (isBooked ||
                                              isUnavailable ||
                                              isPastHour)
                                          ? null
                                          : () => _showTimeSlotConfirmation(
                                              slot, setDialogState),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        decoration: BoxDecoration(
                                          color: isBooked
                                              ? Colors.red.shade50
                                              : isUnavailable
                                                  ? Colors.orange.shade50
                                                  : isPastHour
                                                      ? Colors.grey.shade100
                                                      : (isSelected
                                                          ? Colors
                                                              .green.shade600
                                                          : Colors.white),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isBooked
                                                ? Colors.red.shade300
                                                : isUnavailable
                                                    ? Colors.orange.shade300
                                                    : isPastHour
                                                        ? Colors.grey.shade400
                                                        : (isSelected
                                                            ? Colors
                                                                .green.shade600
                                                            : Colors
                                                                .grey.shade300),
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color:
                                                        Colors.green.shade200,
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 6),
                                                    spreadRadius: 2,
                                                  ),
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: Colors.grey.shade100,
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  slot['label'],
                                                  style: GoogleFonts.poppins(
                                                    color: isBooked
                                                        ? Colors.red.shade600
                                                        : isUnavailable
                                                            ? Colors
                                                                .orange.shade600
                                                            : isPastHour
                                                                ? Colors.grey
                                                                    .shade500
                                                                : (isSelected
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .grey
                                                                        .shade800),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isBooked ||
                                                  isUnavailable ||
                                                  isPastHour) ...[
                                                const SizedBox(height: 2),
                                                Flexible(
                                                  child: Text(
                                                    isPastHour ? _t('past') : _t('off'),
                                                    style: GoogleFonts.poppins(
                                                      color: isBooked
                                                          ? Colors.red.shade600
                                                          : isUnavailable
                                                              ? Colors.orange
                                                                  .shade600
                                                              : Colors.grey
                                                                  .shade500,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 9,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedDateTime != null
                              ? () {
                                  setState(() {
                                    selectedDate = selectedDateTime!;
                                  });
                                  Navigator.pop(context);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedDateTime != null
                                ? Colors.green.shade600
                                : Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: selectedDateTime != null ? 4 : 0,
                          ),
                          child: Text(
                            'Confirm',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
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

  // Helper function to generate time slots
  List<Map<String, dynamic>> _generateTimeSlots() {
    List<Map<String, dynamic>> timeSlots = [];
    final now = DateTime.now();
    final selectedDateOnly =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    final isToday = selectedDateOnly.isAtSameMomentAs(todayOnly);

    for (int hour = 10; hour <= 23; hour++) {
      String period = hour < 12 ? 'AM' : 'PM';
      int displayHour = hour > 12 ? hour - 12 : hour;
      if (hour == 12) displayHour = 12;

      bool isBooked = bookedHours.contains(hour);
      bool isUnavailable = unavailableHours.contains(hour);

      // Check if this hour is in the past (only for today)
      bool isPastHour = false;
      if (isToday) {
        final slotDateTime = DateTime(now.year, now.month, now.day, hour, 0);
        isPastHour = slotDateTime.isBefore(now);
      }

      timeSlots.add({
        'hour': hour,
        'displayHour': displayHour,
        'period': period,
        'label': '${displayHour}:00 ${period}',
        'datetime': selectedDate.copyWith(
            hour: hour, minute: 0, second: 0, millisecond: 0),
        'isBooked': isBooked,
        'isUnavailable': isUnavailable,
        'isPastHour': isPastHour,
      });
    }

    return timeSlots;
  }

  // Show time slot confirmation dialog
  void _showTimeSlotConfirmation(
      Map<String, dynamic> slot, StateSetter setDialogState) {
    final timeLabel = slot['label'] as String;
    final dateLabel = _getDateLabel(selectedDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade50,
                Colors.green.shade100,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.access_time,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Confirm Time Slot',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'Are you sure you want to select this time slot?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Time details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          dateLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time,
                            color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        _confirmTimeSlotSelection(slot, setDialogState);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Confirm',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Confirm time slot selection with animation
  void _confirmTimeSlotSelection(
      Map<String, dynamic> slot, StateSetter setDialogState) {
    setDialogState(() {
      selectedDateTime = slot['datetime'];
    });

    // Show success animation
    _showSuccessAnimation(slot['label'] as String);
  }

  // Show success animation
  void _showSuccessAnimation(String timeLabel) {
    // Play haptic feedback
    HapticFeedback.lightImpact();

    // Show success overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade200,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon with animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Text(
                _t('time_slot_selected'),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                timeLabel,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto close after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  // Get formatted date label
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return '${_t('today')} - ${date.day}/${date.month}';
    } else if (targetDate == tomorrow) {
      return '${_t('tomorrow')} - ${date.day}/${date.month}';
    } else if (targetDate == dayAfter) {
      return '${_t('day_after')} - ${date.day}/${date.month}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildModernDateOption(
      String label, DateTime date, StateSetter setDialogState, IconData icon) {
    final isSelected = _isSameDate(selectedDate, date);
    final isToday = _isSameDate(date, DateTime.now());
    final isTomorrow =
        _isSameDate(date, DateTime.now().add(const Duration(days: 1)));

    String displayLabel = label;
    Color cardColor;
    Color textColor;
    Color iconColor;

    if (isSelected) {
      cardColor = Colors.blue.shade600;
      textColor = Colors.white;
      iconColor = Colors.white;
    } else if (isToday) {
      cardColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      iconColor = Colors.green.shade600;
    } else if (isTomorrow) {
      cardColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      iconColor = Colors.orange.shade600;
    } else {
      cardColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
      iconColor = Colors.purple.shade600;
    }

    return GestureDetector(
      onTap: () async {
        if (_isSameDate(selectedDate, date) || isChangingDate) return;

        setDialogState(() {
          isChangingDate = true;
          selectedDate = date;
          selectedDateTime = null;
        });

        await _fetchBookedTimeSlots(date);

        setDialogState(() {
          isChangingDate = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue.shade200.withOpacity(0.5)
                  : Colors.grey.shade200,
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayLabel,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${date.day}/${date.month}',
                    style: GoogleFonts.poppins(
                      color: textColor.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Inline version of _buildModernDateOption for direct use in page
  Widget _buildModernDateOptionInline(
      String label, DateTime date, IconData icon) {
    final isSelected = _isSameDate(selectedDate, date);
    final isToday = _isSameDate(date, DateTime.now());
    final isTomorrow =
        _isSameDate(date, DateTime.now().add(const Duration(days: 1)));

    String displayLabel = label;
    Color cardColor;
    Color textColor;
    Color iconColor;

    if (isSelected) {
      cardColor = Colors.blue.shade600;
      textColor = Colors.white;
      iconColor = Colors.white;
    } else if (isToday) {
      cardColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      iconColor = Colors.green.shade600;
    } else if (isTomorrow) {
      cardColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      iconColor = Colors.orange.shade600;
    } else {
      cardColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
      iconColor = Colors.purple.shade600;
    }

    return GestureDetector(
      onTap: () async {
        if (_isSameDate(selectedDate, date) || isChangingDate) return;

        setState(() {
          isChangingDate = true;
          selectedDate = date;
          selectedDateTime = null;
        });

        await _fetchBookedTimeSlots(date);

        setState(() {
          isChangingDate = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.blue.shade200.withOpacity(0.5)
                  : Colors.grey.shade200,
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 14,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayLabel,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${date.day}/${date.month}',
                    style: GoogleFonts.poppins(
                      color: textColor.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Select time slot directly without confirmation dialog
  void _selectTimeSlotInline(Map<String, dynamic> slot) {
    setState(() {
      selectedDateTime = slot['datetime'];
      selectedDate = selectedDateTime!;
    });

    // Show success animation
    _showSuccessAnimation(slot['label'] as String);
  }


  Widget _buildFixedPaymentButton() {
    final bool isReadyToProceed = selectedCarId != null &&
        widget.selectedServices.isNotEmpty &&
        selectedSavedAddress != null &&
        selectedDateTime != null &&
        !isSubmittingOrder;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
            spreadRadius: 0,
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('total_amount'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            '${totalPrice.toStringAsFixed(2)} ${_t('riyal')}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: usePackage ? Colors.green.shade700 : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (usePackage) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _t('package'),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isReadyToProceed
                      ? [
                          BoxShadow(
                            color: (usePackage ? Colors.green : Colors.black).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: isReadyToProceed
                      ? () {
                          HapticFeedback.mediumImpact();
                          _submitOrder();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReadyToProceed
                        ? (usePackage ? Colors.green.shade600 : Colors.black)
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    minimumSize: const Size(120, 48),
                  ),
                  child: isSubmittingOrder
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _t('processing'),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(usePackage ? Icons.card_giftcard : Icons.payment, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              usePackage ? _t('use_package') : _t('pay_now'),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

