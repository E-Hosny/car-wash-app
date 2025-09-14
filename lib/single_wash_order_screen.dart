import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_car_screen.dart';
import 'map_picker_screen.dart';
import 'payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/package_service.dart';
import 'utils/debug_helper.dart';
import 'widgets/order_summary_card.dart';
import 'main_navigation_screen.dart';
import 'services/config_service.dart';

class SingleWashOrderScreen extends StatefulWidget {
  final String token;

  const SingleWashOrderScreen({super.key, required this.token});

  @override
  State<SingleWashOrderScreen> createState() => _SingleWashOrderScreenState();
}

class _SingleWashOrderScreenState extends State<SingleWashOrderScreen> {
  double? latitude;
  double? longitude;
  LatLng? selectedLocation;
  String? selectedAddress;

  List services = [];
  List cars = [];
  List selectedServices = [];
  int? selectedCarId;
  double totalPrice = 0;
  bool usePackage = false;
  Map<String, dynamic>? userPackage;
  List<dynamic> availableServices = [];

  bool useCurrentTime = true;
  DateTime? selectedDateTime;

  bool isMapInteracting = false;
  bool isSubmittingOrder = false;

  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, dynamic>? selectedSavedAddress;
  bool isLoadingAddresses = false;
  bool packagesEnabled = true;

  // Track if user has explicitly selected an address
  bool hasSelectedAddress = false;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    print('🚀 SingleWashOrderScreen initState started');
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Load configuration first
      packagesEnabled = await ConfigService.fetchPackagesEnabled();

      // Fetch all required data in parallel
      await Future.wait([
        _fetchServices(),
        _fetchUserCars(),
        _determineCurrentPosition(),
        _fetchSavedAddresses(),
        if (packagesEnabled) _checkUserPackage(),
      ]);

      // Auto-select most recent car and address
      await _autoSelectRecentData();

      setState(() {
        isLoading = false;
      });

      print('✅ SingleWashOrderScreen initialization completed successfully');
    } catch (e) {
      print('❌ Error in SingleWashOrderScreen initialization: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data. Please try again.';
      });
    }
  }

  Future<void> _autoSelectRecentData() async {
    try {
      // Auto-select the most recently added car (last in the list)
      if (cars.isNotEmpty) {
        setState(() {
          selectedCarId = cars.last['id'];
        });
        print(
            '🚗 Auto-selected most recent car: ${cars.last['brand']['name']} ${cars.last['model']['name']}');
      }

      // Auto-select the most recently used address (last in the list)
      if (savedAddresses.isNotEmpty) {
        final recentAddress = savedAddresses.last;
        setState(() {
          selectedSavedAddress = recentAddress;
          selectedLocation = LatLng(
            double.parse(recentAddress['latitude'].toString()),
            double.parse(recentAddress['longitude'].toString()),
          );
          selectedAddress = recentAddress['address'];
          hasSelectedAddress = true; // User has a saved address
        });
        print(
            '📍 Auto-selected most recent address: ${recentAddress['label']} - ${recentAddress['address']}');
      } else {
        // No saved addresses, reset selection
        setState(() {
          hasSelectedAddress = false;
          selectedSavedAddress = null;
          selectedAddress = null;
        });
        print('📍 No saved addresses found');
      }
    } catch (e) {
      print('❌ Error in auto-selecting recent data: $e');
    }
  }

  Future<void> _determineCurrentPosition() async {
    try {
      // Request location permission
      var permission = await Permission.location.request();

      if (permission.isGranted) {
        // Try to get current position
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (!mounted) return;
        setState(() {
          if (selectedLocation == null) {
            // Only set if not auto-selected from saved addresses
            latitude = pos.latitude;
            longitude = pos.longitude;
            selectedLocation = LatLng(latitude!, longitude!);
          } else {
            latitude = pos.latitude;
            longitude = pos.longitude;
          }
        });
        print('✅ Current position obtained: $latitude, $longitude');
      } else {
        // If permission denied, use default location (Dubai)
        print('⚠️ Location permission denied, using default location');
        _setDefaultLocation();
      }
    } catch (e) {
      print('❌ Error getting current position: $e');
      // Use default location on error
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    if (!mounted) return;
    setState(() {
      if (selectedLocation == null) {
        // Only set if not auto-selected from saved addresses
        // Default location: Dubai, UAE
        latitude = 25.2048;
        longitude = 55.2708;
        selectedLocation = LatLng(latitude!, longitude!);
      } else {
        latitude = 25.2048;
        longitude = 55.2708;
      }
    });
    print('📍 Using default location: Dubai, UAE ($latitude, $longitude)');
  }

  Future<void> _fetchServices() async {
    try {
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      print('🔗 Using BASE_URL for services: $baseUrl');

      if (baseUrl.isEmpty) {
        print('Error: BASE_URL not configured');
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/services'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final servicesData = jsonDecode(res.body);
        DebugHelper.logApiResponse('services', servicesData);
        setState(() {
          services = servicesData;
        });
        DebugHelper.logServiceData(services);
      }
    } catch (e) {
      print('Error fetching services: $e');
    }
  }

  Future<void> _fetchUserCars() async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        print('Error: BASE_URL not configured');
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/cars'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          cars = jsonDecode(res.body);
        });
      }
    } catch (e) {
      print('Error fetching user cars: $e');
    }
  }

  Future<void> _fetchSavedAddresses() async {
    setState(() => isLoadingAddresses = true);
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        print('Error: BASE_URL not configured');
        setState(() => isLoadingAddresses = false);
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/addresses'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        setState(() {
          savedAddresses =
              List<Map<String, dynamic>>.from(jsonDecode(res.body));
          isLoadingAddresses = false;
        });
      } else {
        setState(() => isLoadingAddresses = false);
      }
    } catch (e) {
      print('Error fetching saved addresses: $e');
      setState(() => isLoadingAddresses = false);
    }
  }

  Future<void> _checkUserPackage() async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        print('Error: BASE_URL not configured');
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/packages/my/current'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          userPackage = data['data'];
        });
        _fetchAvailableServices();
      }
    } catch (e) {
      print('Error checking user package: $e');
      // Handle error silently
    }
  }

  Future<void> _fetchAvailableServices() async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        print('Error: BASE_URL not configured');
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/packages/my/services'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        DebugHelper.logApiResponse('packages/my/services', data);
        setState(() {
          availableServices = data['data']['available_services'] ?? [];
        });
        DebugHelper.logAvailableServices(availableServices);
      }
    } catch (e) {
      print('Error fetching available services: $e');
      // Handle error silently
    }
  }

  void _toggleService(int id, double price, bool selected) {
    setState(() {
      if (selected) {
        selectedServices.add(id);
        if (!usePackage) {
          totalPrice += price;
        }
      } else {
        selectedServices.remove(id);
        if (!usePackage) {
          totalPrice -= price;
        }
      }
      // Ensure totalPrice doesn't go negative
      if (totalPrice < 0) {
        totalPrice = 0;
      }
    });
  }

  void _togglePackageUsage(bool value) {
    setState(() {
      usePackage = value;
      if (usePackage) {
        totalPrice = 0; // Free when using package
      } else {
        // Recalculate total based on selected services
        totalPrice = 0;
        for (int serviceId in selectedServices) {
          try {
            final service = services.firstWhere((s) => s['id'] == serviceId);
            final price = double.tryParse(service['price'].toString()) ?? 0.0;
            totalPrice += price;
          } catch (e) {
            print('Error calculating price for service $serviceId: $e');
            // Continue with other services
          }
        }
      }
      // Ensure totalPrice doesn't go negative
      if (totalPrice < 0) {
        totalPrice = 0;
      }
    });
  }

  Future<void> _submitOrder() async {
    if (selectedCarId == null ||
        selectedServices.isEmpty ||
        !hasSelectedAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service, car, and address'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      isSubmittingOrder = true;
    });

    try {
      // Create order data
      final orderData = {
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'address': selectedAddress ?? 'Selected from map',
        'street': selectedSavedAddress?['street'],
        'building': selectedSavedAddress?['building'],
        'floor': selectedSavedAddress?['floor'],
        'apartment': selectedSavedAddress?['apartment'],
        'car_id': selectedCarId,
        'services': selectedServices,
        'scheduled_at':
            useCurrentTime ? null : selectedDateTime?.toIso8601String(),
        'total': totalPrice,
        'use_package': usePackage,
      };

      // Generate unique order ID
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // Navigate to payment screen
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

      // Check if payment was successful
      if (result == true) {
        // Navigate to orders screen
        _navigateToOrders();
      } else {
        // Payment failed or was cancelled - show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order was not created due to payment failure'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error submitting order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
          initialIndex: 2, // Orders tab
        ),
      ),
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
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Address Details',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                      labelText: 'Label (e.g. Home, Work)'),
                ),
                TextField(
                  controller: streetController,
                  decoration: const InputDecoration(labelText: 'Street'),
                ),
                TextField(
                  controller: buildingController,
                  decoration: const InputDecoration(labelText: 'Building'),
                ),
                TextField(
                  controller: floorController,
                  decoration: const InputDecoration(labelText: 'Floor'),
                ),
                TextField(
                  controller: apartmentController,
                  decoration: const InputDecoration(labelText: 'Apartment'),
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 12),
                Text('Location: $address',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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
                                content: Text(
                                    'Configuration error: BASE_URL not found'),
                                backgroundColor: Colors.red),
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
                          await _fetchSavedAddresses();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Address saved!'),
                                backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Failed to save address'),
                                backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        setState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Error saving address: ${e.toString()}'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
              child: isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Calculate total points used for selected services
  int _calculateTotalPointsUsed() {
    if (!usePackage || userPackage == null || availableServices.isEmpty)
      return 0;

    int totalPoints = 0;
    for (var service in selectedServices) {
      // Handle both Map and int service types
      int serviceId;
      if (service is Map && service.containsKey('id')) {
        serviceId = service['id'] as int;
      } else if (service is int) {
        serviceId = service;
      } else {
        continue; // Skip invalid service
      }

      final pointsRequired = PackageService.getPointsRequiredForService(
        availableServices,
        serviceId,
      );
      totalPoints += pointsRequired;
    }
    return totalPoints;
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Single Car Wash',
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
        backgroundColor: Colors.white,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading your preferences...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Single Car Wash',
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
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Single Car Wash',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics:
              isMapInteracting ? const NeverScrollableScrollPhysics() : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Services Selection (First)
              _buildServicesSection(),
              const SizedBox(height: 28),

              // Auto-selected Car Section (Second)
              _buildSelectedCarSection(),
              const SizedBox(height: 28),

              // Auto-selected Address Section (Third)
              _buildSelectedAddressSection(),
              const SizedBox(height: 28),

              // Schedule Section
              _buildScheduleSection(),
              const SizedBox(height: 28),

              // Package Section (if available)
              if (packagesEnabled && userPackage != null) ...[
                _buildPackageSection(),
                const SizedBox(height: 28),
              ],

              // Order Summary
              OrderSummaryCard(
                totalPrice: totalPrice,
                usePackage: usePackage,
                selectedServicesCount: selectedServices.length,
                remainingPoints: userPackage?['remaining_points'],
                totalPointsUsed: _calculateTotalPointsUsed(),
              ),

              const SizedBox(height: 24),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
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
            _sectionTitle('Selected Car'),
            if (selectedCarId != null)
              TextButton(
                onPressed: () {
                  _showCarSelectionDialog();
                },
                child: Text(
                  'Change',
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_car,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No cars available',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a car to continue',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final added = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddCarScreen(token: widget.token),
                        ),
                      );
                      if (added == true) {
                        await _fetchUserCars();
                        await _autoSelectRecentData();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Car'),
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
          // Display selected car
          Builder(
            builder: (context) {
              final car = cars.firstWhere((c) => c['id'] == selectedCarId);
              return Card(
                color: Colors.green[50],
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${car['brand']['name']} ${car['model']['name']}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Year: ${car['year']['year']} • Color: ${car['color']}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      if (car['license_plate'] != null &&
                          car['license_plate'].toString().isNotEmpty)
                        Text(
                          'License Plate: ${car['license_plate']}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Select Car',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cars.length,
                  itemBuilder: (context, index) {
                    final car = cars[index];
                    return RadioListTile<int>(
                      value: car['id'],
                      groupValue: selectedCarId,
                      title: Text(
                          '${car['brand']['name']} ${car['model']['name']}'),
                      subtitle: Text(
                          'Year: ${car['year']['year']} • Color: ${car['color']}'),
                      onChanged: (val) {
                        setState(() {
                          selectedCarId = val;
                        });
                        Navigator.pop(context);
                      },
                      activeColor: Colors.black,
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.add_circle_outline, color: Colors.black),
                title: Text(
                  'Add New Car',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final added = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddCarScreen(token: widget.token),
                    ),
                  );
                  if (added == true) {
                    await _fetchUserCars();
                    await _autoSelectRecentData();
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Services'),
        ...services.map((s) {
          final price = double.tryParse(s['price'].toString()) ?? 0.0;
          final isAvailableInPackage = usePackage &&
              availableServices.any((service) => service['id'] == s['id']);
          final pointsRequired = usePackage && isAvailableInPackage
              ? PackageService.getPointsRequiredForService(
                  availableServices, s['id'])
              : null;

          final isSelected = selectedServices.contains(s['id']);

          return GestureDetector(
            onTap: () => _toggleService(s['id'], price, !isSelected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? Colors.black.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.black.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.05),
                    blurRadius: isSelected ? 8 : 4,
                    offset: Offset(0, isSelected ? 4 : 2),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Custom checkbox
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.transparent,
                        border: Border.all(
                          color:
                              isSelected ? Colors.black : Colors.grey.shade400,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),

                    // Service content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Service name and price/points
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  s['name'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Price or points badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: usePackage && isAvailableInPackage
                                      ? Colors.black
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: usePackage && isAvailableInPackage
                                      ? null
                                      : Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  usePackage && isAvailableInPackage
                                      ? '${pointsRequired ?? 0} Points'
                                      : '${price.toStringAsFixed(0)} AED',
                                  style: GoogleFonts.poppins(
                                    color: usePackage && isAvailableInPackage
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Service description
                          if (s['description'] != null &&
                              s['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              s['description'],
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Selection indicator
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSelectedAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Selected Address'),
            TextButton(
              onPressed: () {
                _showAddressSelectionDialog();
              },
              child: Text(
                selectedSavedAddress == null ? 'Select' : 'Change',
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No address selected',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap here to select or add an address',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
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
          // Display selected address
          Card(
            color: Colors.green[50],
            child: ListTile(
              onTap: () {
                _showAddressSelectionDialog();
              },
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                selectedSavedAddress!['label'] ??
                    selectedSavedAddress!['address'] ??
                    'Address',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${selectedSavedAddress!['street'] ?? ''} ${selectedSavedAddress!['building'] ?? ''} ${selectedSavedAddress!['floor'] ?? ''} ${selectedSavedAddress!['apartment'] ?? ''}\n${selectedSavedAddress!['address'] ?? ''}',
                style: const TextStyle(fontSize: 13),
              ),
              trailing: const Icon(Icons.edit, color: Colors.green),
            ),
          ),
        ],
      ],
    );
  }

  void _showAddressSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Select Address',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: savedAddresses.length,
                  itemBuilder: (context, index) {
                    final addr = savedAddresses[index];
                    return ListTile(
                      title:
                          Text(addr['label'] ?? addr['address'] ?? 'Address'),
                      subtitle: Text(
                        '${addr['street'] ?? ''} ${addr['building'] ?? ''}\n${addr['address'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          selectedSavedAddress = addr;
                          selectedLocation = LatLng(
                            double.parse(addr['latitude'].toString()),
                            double.parse(addr['longitude'].toString()),
                          );
                          selectedAddress = addr['address'];
                          hasSelectedAddress =
                              true; // User explicitly selected an address
                        });
                        Navigator.pop(context);
                      },
                      trailing: selectedSavedAddress != null &&
                              selectedSavedAddress!['id'] == addr['id']
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_location_alt),
                title: const Text('Add New Address'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    if (latitude == null || longitude == null) {
                      // If no location available, show error and try to get default location
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'No location available. Please wait or check location permissions.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      // Try to get default location
                      _setDefaultLocation();
                      return;
                    }

                    print(
                        '🗺️ Opening map picker with location: $latitude, $longitude');
                    final picked = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapPickerScreen(
                          initialLocation:
                              selectedLocation ?? LatLng(latitude!, longitude!),
                        ),
                      ),
                    );
                    if (picked != null &&
                        picked is Map &&
                        picked['latlng'] != null &&
                        picked['address'] != null) {
                      await _addNewAddressDialog(
                          picked['latlng'], picked['address']);
                      await _autoSelectRecentData(); // Auto-select the newly added address
                    }
                  } catch (e) {
                    print('❌ Error opening map picker: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening map: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Schedule'),
        SwitchListTile(
          title: const Text('Request for now', style: TextStyle(fontSize: 16)),
          value: useCurrentTime,
          onChanged: (val) {
            setState(() {
              useCurrentTime = val;
              if (val) selectedDateTime = null;
            });
          },
        ),
        if (!useCurrentTime)
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              borderRadius: BorderRadius.circular(24),
            ),
            child: ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      selectedDateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
              child: Text(
                selectedDateTime != null
                    ? 'Selected: ${selectedDateTime.toString()}'
                    : 'Schedule for later',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPackageSection() {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'Your Current Package',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '${userPackage!['package']['name']} - ${userPackage!['remaining_points']} points remaining',
              style: TextStyle(fontSize: 14, color: Colors.black),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: usePackage,
                  onChanged: _togglePackageUsage,
                  activeColor: Colors.black,
                ),
                Text('Use Package', style: TextStyle(color: Colors.black)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        borderRadius: BorderRadius.circular(24),
      ),
      child: ElevatedButton.icon(
        onPressed: (selectedCarId != null &&
                selectedServices.isNotEmpty &&
                hasSelectedAddress &&
                !isSubmittingOrder)
            ? _submitOrder
            : null,
        icon: isSubmittingOrder
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(usePackage ? Icons.card_giftcard : Icons.payment),
        label: Text(
          isSubmittingOrder
              ? 'Processing...'
              : (usePackage ? 'Use Package Points' : 'Proceed to Payment'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: usePackage ? Colors.green : Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}
