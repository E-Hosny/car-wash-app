import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'map_picker_with_search_screen.dart';
import 'payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/package_service.dart';
import 'main_navigation_screen.dart';
import 'add_car_screen.dart';

class MultiCarOrderScreen extends StatefulWidget {
  final String token;

  const MultiCarOrderScreen({super.key, required this.token});

  @override
  State<MultiCarOrderScreen> createState() => _MultiCarOrderScreenState();
}

class _MultiCarOrderScreenState extends State<MultiCarOrderScreen> {
  double? latitude;
  double? longitude;
  LatLng? selectedLocation;
  String? selectedAddress;

  List services = [];
  List cars = [];
  List<Map<String, dynamic>> selectedCars = [];
  double totalPrice = 0;
  bool usePackage = false;
  Map<String, dynamic>? userPackage;
  List<dynamic> availableServices = [];

  bool isLoadingServices = true;
  bool isLoadingCars = true;

  DateTime? selectedDateTime;
  DateTime selectedDate =
      DateTime.now(); // التاريخ المختار (اليوم، الغد، بعد الغد)

  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, dynamic>? selectedSavedAddress;
  bool isLoadingAddresses = false;

  // Booked time slots
  List<int> bookedHours = [];
  List<int> unavailableHours = [];
  bool isLoadingTimeSlots = false;
  bool isChangingDate = false; // Flag to prevent multiple date changes

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    try {
      // Fetch all required data in parallel
      await Future.wait([
        fetchUserCars(),
        fetchServices(),
        determineCurrentPosition(),
        fetchSavedAddresses(),
        _fetchBookedTimeSlots(),
        checkUserPackage(),
      ]);

      // Auto-select most recent address
      await _autoSelectRecentAddress();

      // Validate existing selected cars after data is loaded
      _validateSelectedCars();
    } catch (e) {
      debugPrint('Error initializing data: $e');
    }
  }

  Future<void> _autoSelectRecentAddress() async {
    try {
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
        });
        debugPrint(
            '📍 Auto-selected most recent address: ${recentAddress['label']} - ${recentAddress['address']}');
      } else {
        // No saved addresses, reset selection
        setState(() {
          selectedSavedAddress = null;
          selectedAddress = null;
        });
        debugPrint('📍 No saved addresses found');
      }
    } catch (e) {
      debugPrint('❌ Error in auto-selecting recent address: $e');
    }
  }

  void _validateSelectedCars() {
    if (selectedCars.isEmpty || cars.isEmpty) return;

    bool hasInvalidCars = false;
    List<Map<String, dynamic>> validCars = [];

    for (var selectedCar in selectedCars) {
      final carId = selectedCar['car_id'];
      final userCar = cars.firstWhere(
        (car) => car['id'] == carId,
        orElse: () => null,
      );

      if (userCar != null) {
        validCars.add(selectedCar);
      } else {
        hasInvalidCars = true;
        debugPrint('❌ Removing invalid car ID: $carId');
      }
    }

    if (hasInvalidCars) {
      setState(() {
        selectedCars = validCars;
        calculateTotalPrice();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Some selected cars were removed because they don\'t belong to your account.'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> determineCurrentPosition() async {
    try {
      // Request location permission
      var permission = await Permission.location.request();

      if (permission.isGranted) {
        // Try to get current position
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (!mounted) return;
        setState(() {
          latitude = pos.latitude;
          longitude = pos.longitude;
          selectedLocation = LatLng(latitude!, longitude!);
        });
        debugPrint('✅ Current position obtained: $latitude, $longitude');
      } else {
        // If permission denied, use default location (Dubai)
        debugPrint('⚠️ Location permission denied, using default location');
        _setDefaultLocation();
      }
    } catch (e) {
      debugPrint('❌ Error getting current position: $e');
      // Use default location on error
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    if (!mounted) return;
    setState(() {
      // Default location: Dubai, UAE
      latitude = 25.2048;
      longitude = 55.2708;
      selectedLocation = LatLng(latitude!, longitude!);
    });
    debugPrint('📍 Using default location: Dubai, UAE ($latitude, $longitude)');
  }

  Future<void> fetchServices() async {
    try {
      debugPrint('Fetching services...');
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint('Error: BASE_URL not configured');
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/services'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      debugPrint('Services API response status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        debugPrint('Services loaded: ${decoded.length} services');
        setState(() {
          services = decoded;
          isLoadingServices = false;
        });
      } else {
        debugPrint('Failed to fetch services: ${res.body}');
        setState(() {
          isLoadingServices = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching services: $e');
    }
  }

  Future<void> fetchUserCars() async {
    try {
      debugPrint('Fetching user cars...');
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint('Error: BASE_URL not configured');
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/cars'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      debugPrint('🚗 fetchUserCars API response status: ${res.statusCode}');
      debugPrint('🚗 fetchUserCars API response body: ${res.body}');

      if (res.statusCode == 200) {
        if (!mounted) return;
        final decoded = jsonDecode(res.body);
        debugPrint('✅ fetchUserCars loaded: ${decoded.length} cars');

        // Debug each car
        for (int i = 0; i < decoded.length; i++) {
          final car = decoded[i];
          debugPrint(
              '  🚗 fetchUserCars Car ${i + 1}: ID=${car['id']}, UserID=${car['user_id']}, Brand=${car['brand']?['name']}, Model=${car['model']?['name']}');
        }

        setState(() {
          cars = decoded;
          isLoadingCars = false;
        });
      } else {
        debugPrint('Failed to fetch cars: ${res.body}');
        if (!mounted) return;
        setState(() {
          isLoadingCars = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user cars: $e');
    }
  }

  Future<void> fetchSavedAddresses() async {
    setState(() => isLoadingAddresses = true);
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint('Error: BASE_URL not configured');
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
      debugPrint('Error fetching saved addresses: $e');
      setState(() => isLoadingAddresses = false);
    }
  }

  Future<void> _fetchBookedTimeSlots([DateTime? date]) async {
    setState(() => isLoadingTimeSlots = true);
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint('Error: BASE_URL not configured');
        setState(() => isLoadingTimeSlots = false);
        return;
      }

      final targetDate = date ?? selectedDate;
      final dateString =
          targetDate.toIso8601String().split('T')[0]; // YYYY-MM-DD format

      debugPrint('🔍 Fetching booked time slots for date: $dateString');

      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/booked-time-slots?date=$dateString'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📡 Response status: ${res.statusCode}');
      debugPrint('📡 Response body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        debugPrint('📊 Parsed data: $data');

        setState(() {
          bookedHours = List<int>.from(data['booked_hours'] ?? []);
          unavailableHours = List<int>.from(data['unavailable_hours'] ?? []);
          isLoadingTimeSlots = false;
        });
        debugPrint('📅 Booked hours loaded: $bookedHours');
        debugPrint('🚫 Unavailable hours loaded: $unavailableHours');
      } else {
        debugPrint('❌ Failed to fetch booked time slots: ${res.statusCode}');
        debugPrint('❌ Response body: ${res.body}');
        setState(() {
          bookedHours = []; // Reset to empty if API fails
          unavailableHours = []; // Reset to empty if API fails
          isLoadingTimeSlots = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching booked time slots: $e');
      setState(() {
        bookedHours = []; // Reset to empty on error
        unavailableHours = []; // Reset to empty on error
        isLoadingTimeSlots = false;
      });
    }
  }

  Future<void> checkUserPackage() async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint('Error: BASE_URL not configured');
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
        fetchAvailableServices();
      }
    } catch (e) {
      debugPrint('Error checking user package: $e');
    }
  }

  Future<void> fetchAvailableServices() async {
    try {
      debugPrint('Fetching available services...');
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        debugPrint('Error: BASE_URL not configured');
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/packages/my/services'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      debugPrint('Available services API response status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final services = data['data']['available_services'] ?? [];
        debugPrint('Available services loaded: ${services.length} services');
        setState(() {
          availableServices = services;
        });

        // Debug: Print each service and its points
        for (var service in services) {
          debugPrint(
              'Available service: ${service['service']?['name']} - ${service['points_required']} points');
        }
      } else {
        debugPrint('Failed to fetch available services: ${res.body}');
      }
    } catch (e) {
      debugPrint('Error fetching available services: $e');
    }
  }

  void addCarToOrder() {
    debugPrint('Add Car button pressed');
    debugPrint('Cars count: ${cars.length}');
    debugPrint('Services count: ${services.length}');
    debugPrint('Available services count: ${availableServices.length}');

    // Check if data is still loading
    if (isLoadingServices || isLoadingCars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading data, please wait...'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    // Check if we have necessary data
    if (cars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cars available. Please add a car first.'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    if (services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No services available. Please try again later.'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    // Check if all cars are already selected
    final availableCarIds = cars.map((c) => c['id']).toSet();
    final selectedCarIds = selectedCars.map((c) => c['car_id']).toSet();
    final remainingCars = availableCarIds.difference(selectedCarIds);

    if (remainingCars.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'All your cars (${cars.length}) are already selected. You cannot add more cars.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    debugPrint('🚗 Add Car Dialog:');
    debugPrint('  Available cars: ${availableCarIds.toList()}');
    debugPrint('  Selected cars: ${selectedCarIds.toList()}');
    debugPrint('  Remaining cars: ${remainingCars.toList()}');

    try {
      debugPrint('Showing CarSelectionDialog');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return CarSelectionDialog(
            cars: cars,
            services: services,
            usePackage: usePackage,
            availableServices: availableServices,
            token: widget.token,
            onCarsUpdated: () => fetchUserCars(),
            onCarAdded: (carData) {
              debugPrint('Car added successfully: $carData');
              debugPrint('Points in carData: ${carData['points_used']}');

              // Validate that the car belongs to the user
              final carId = carData['car_id'];
              final userCar = cars.firstWhere(
                (car) => car['id'] == carId,
                orElse: () => null,
              );

              if (userCar == null) {
                debugPrint('❌ Error: Car ID $carId not found in user cars!');
                debugPrint(
                    'Available cars: ${cars.map((c) => '${c['id']}: ${c['brand']?['name']} ${c['model']?['name']}').toList()}');

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Error: Selected car does not belong to you. Please try refreshing the car list.'),
                    backgroundColor: Colors.red,
                    action: SnackBarAction(
                      label: 'Refresh',
                      textColor: Colors.white,
                      onPressed: () {
                        fetchUserCars(); // Refresh cars list
                      },
                    ),
                  ),
                );
                return;
              }

              setState(() {
                selectedCars.add(carData);
                calculateTotalPrice();
                debugPrint(
                    'Selected cars after adding: ${selectedCars.length}');
                debugPrint(
                    'Added car: ${userCar['brand']?['name']} ${userCar['model']?['name']} (ID: $carId)');
                for (var i = 0; i < selectedCars.length; i++) {
                  debugPrint(
                      'Car $i points: ${selectedCars[i]['points_used']}');
                }
              });
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error showing dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening car selection: ${e.toString()}'),
          backgroundColor: Colors.black,
        ),
      );
    }
  }

  void editCarServices(int index) {
    showDialog(
      context: context,
      builder: (context) => CarSelectionDialog(
        cars: cars,
        services: services,
        usePackage: usePackage,
        availableServices: availableServices,
        token: widget.token,
        onCarsUpdated: () => fetchUserCars(),
        initialCarData: selectedCars[index],
        onCarAdded: (carData) {
          setState(() {
            selectedCars[index] = carData;
            calculateTotalPrice();
          });
        },
      ),
    );
  }

  void removeCarFromOrder(int index) {
    setState(() {
      selectedCars.removeAt(index);
      calculateTotalPrice();
    });
  }

  void calculateTotalPrice() {
    totalPrice = 0.0;
    for (var car in selectedCars) {
      if (!usePackage) {
        totalPrice += (car['subtotal'] as double?) ?? 0.0;
      }
    }
  }

  // Calculate points used for a specific car based on its services
  int calculateCarPoints(Map<String, dynamic> carData) {
    if (!usePackage || carData['services'] == null) return 0;

    final services = carData['services'] as List;
    int totalPoints = 0;

    debugPrint('Calculating points for car: ${carData['car_id']}');
    debugPrint('Services for this car: $services');

    for (var serviceId in services) {
      final points = PackageService.getPointsRequiredForService(
          availableServices, serviceId);
      totalPoints += points;
      debugPrint('Service $serviceId contributes $points points');
    }

    debugPrint('Total points for car: $totalPoints');
    return totalPoints;
  }

  void togglePackageUsage(bool value) {
    debugPrint('Toggling package usage to: $value');
    setState(() {
      usePackage = value;
      calculateTotalPrice();

      // Recalculate points for existing selected cars
      for (var car in selectedCars) {
        if (car['services'] != null) {
          final services = car['services'] as List;
          int carPoints = 0;
          for (var serviceId in services) {
            carPoints += PackageService.getPointsRequiredForService(
                availableServices, serviceId);
          }
          final oldPoints = car['points_used'];
          car['points_used'] = carPoints;
          debugPrint(
              'Car ${car['car_id']} points updated: $oldPoints -> $carPoints');
        }
      }
    });
  }

  Future<void> submitMultiCarOrder() async {
    if (selectedCars.isEmpty ||
        selectedLocation == null ||
        selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select location, add at least one car, and select a time slot'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    // Check for duplicate cars first
    final carIds = selectedCars.map((car) => car['car_id']).toList();
    final uniqueCarIds = carIds.toSet().toList();

    if (carIds.length != uniqueCarIds.length) {
      debugPrint('❌ Duplicate cars detected in selected cars!');
      debugPrint('Car IDs: $carIds');
      debugPrint('Unique Car IDs: $uniqueCarIds');

      // Find duplicates
      final duplicates = <int>[];
      for (int i = 0; i < carIds.length; i++) {
        for (int j = i + 1; j < carIds.length; j++) {
          if (carIds[i] == carIds[j] && !duplicates.contains(carIds[i])) {
            duplicates.add(carIds[i]);
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Duplicate cars detected! Car IDs: ${duplicates.join(', ')}. Please remove duplicates.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Clear All',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                selectedCars.clear();
                calculateTotalPrice();
              });
            },
          ),
        ),
      );
      return;
    }

    // Validate that all cars have valid data and belong to user
    for (int i = 0; i < selectedCars.length; i++) {
      final car = selectedCars[i];
      if (car['car_id'] == null ||
          car['services'] == null ||
          (car['services'] as List).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Car ${i + 1} has invalid data. Please remove and re-add it.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if car belongs to user (from cars list)
      final carId = car['car_id'];
      final userCar = cars.firstWhere(
        (userCar) => userCar['id'] == carId,
        orElse: () => null,
      );

      if (userCar == null) {
        debugPrint('❌ Car ID $carId not found in user cars list!');
        debugPrint('Available car IDs: ${cars.map((c) => c['id']).toList()}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Car ${i + 1} (ID: $carId) does not belong to you. Please remove and select a valid car.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Validate service IDs are integers
      final services = car['services'] as List;
      for (int j = 0; j < services.length; j++) {
        if (services[j] is! int) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Car ${i + 1} has invalid service ID at position $j: ${services[j]}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    debugPrint('=== Validation passed, proceeding with order submission ===');

    // Force refresh user cars before creating order to ensure data consistency
    debugPrint('🔄 Refreshing user cars before order creation...');
    await fetchUserCars();

    // Re-validate after refresh
    bool hasInvalidCarsAfterRefresh = false;
    for (var selectedCar in selectedCars) {
      final carId = selectedCar['car_id'];
      final userCar = cars.firstWhere(
        (car) => car['id'] == carId,
        orElse: () => null,
      );

      if (userCar == null) {
        hasInvalidCarsAfterRefresh = true;
        debugPrint('❌ After refresh, car ID $carId still not found!');
      } else {
        debugPrint('✅ After refresh, car ID $carId confirmed as owned');
      }
    }

    if (hasInvalidCarsAfterRefresh) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '❌ Car ownership validation failed after refresh. Please re-select your cars.'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Refresh',
            textColor: Colors.white,
            onPressed: () async {
              setState(() {
                selectedCars.clear();
              });
              await fetchUserCars();
            },
          ),
        ),
      );
      return;
    }

    // Detailed validation of order data before sending
    debugPrint('=== Pre-submission Data Validation ===');
    debugPrint('usePackage: $usePackage');
    debugPrint('selectedDateTime: $selectedDateTime');
    debugPrint('selectedLocation: $selectedLocation');
    debugPrint('selectedAddress: $selectedAddress');
    debugPrint('selectedSavedAddress: $selectedSavedAddress');
    debugPrint('totalPrice: $totalPrice');
    debugPrint('selectedCars.length: ${selectedCars.length}');

    // Validate each car's data structure
    for (int i = 0; i < selectedCars.length; i++) {
      final car = selectedCars[i];
      debugPrint('=== Car $i Validation ===');
      debugPrint('car keys: ${car.keys.toList()}');
      debugPrint(
          'car_id: ${car['car_id']} (type: ${car['car_id'].runtimeType})');
      debugPrint(
          'services: ${car['services']} (type: ${car['services'].runtimeType})');
      debugPrint(
          'subtotal: ${car['subtotal']} (type: ${car['subtotal'].runtimeType})');
      debugPrint(
          'points_used: ${car['points_used']} (type: ${car['points_used'].runtimeType})');

      if (car['services'] is List) {
        final services = car['services'] as List;
        debugPrint('services.length: ${services.length}');
        for (int j = 0; j < services.length; j++) {
          debugPrint(
              '  service[$j]: ${services[j]} (type: ${services[j].runtimeType})');
        }
      }
    }

    // Debug address information
    debugPrint('=== Order Submission Debug ===');
    debugPrint(
        'Selected location: ${selectedLocation!.latitude}, ${selectedLocation!.longitude}');
    debugPrint('Selected address: $selectedAddress');
    debugPrint('Selected saved address: $selectedSavedAddress');
    debugPrint('Selected date time: $selectedDateTime');
    if (selectedSavedAddress != null) {
      debugPrint('Address details:');
      debugPrint('  Street: ${selectedSavedAddress!['street']}');
      debugPrint('  Building: ${selectedSavedAddress!['building']}');
      debugPrint('  Floor: ${selectedSavedAddress!['floor']}');
      debugPrint('  Apartment: ${selectedSavedAddress!['apartment']}');
    }

    final orderData = {
      'latitude': selectedLocation!.latitude,
      'longitude': selectedLocation!.longitude,
      'address': selectedAddress ?? 'Selected from map',
      'street': selectedSavedAddress?['street'],
      'building': selectedSavedAddress?['building'],
      'floor': selectedSavedAddress?['floor'],
      'apartment': selectedSavedAddress?['apartment'],
      'scheduled_at': selectedDateTime?.toIso8601String(),
      'use_package': usePackage,
      'cars': selectedCars
          .map((car) => {
                'car_id': car['car_id'],
                'services': car['services'],
              })
          .toList(),
    };

    debugPrint('Final order data: $orderData');
    debugPrint('Cars data:');
    for (int i = 0; i < selectedCars.length; i++) {
      final car = selectedCars[i];
      debugPrint('  Car ${i + 1}:');
      debugPrint('    car_id: ${car['car_id']} (${car['car_id'].runtimeType})');
      debugPrint(
          '    services: ${car['services']} (${car['services'].runtimeType})');
      debugPrint(
          '    subtotal: ${car['subtotal']} (${car['subtotal'].runtimeType})');
      debugPrint(
          '    points_used: ${car['points_used']} (${car['points_used'].runtimeType})');

      // Validate service IDs
      if (car['services'] is List) {
        final services = car['services'] as List;
        for (int j = 0; j < services.length; j++) {
          debugPrint(
              '      service[$j]: ${services[j]} (${services[j].runtimeType})');
        }
      }
    }

    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            token: widget.token,
            amount: totalPrice,
            orderId: orderId,
            orderData: orderData,
            isMultiCar: true,
          ),
        ),
      );

      // Check if payment was successful before navigating
      if (result == true) {
        debugPrint('Payment successful, navigating to orders');
        _navigateToOrders();
      } else {
        debugPrint('Payment failed or was cancelled');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order was not created due to payment failure'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error during payment process');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: ${e.toString()}');
      debugPrint('Error Details: $e');

      // Show user-friendly error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Error:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${e.toString()}'),
              SizedBox(height: 8),
              Text('Please check the console for detailed error information.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 10),
        ),
      );
    }
  }

  void _navigateToOrders() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainNavigationScreen(
          token: widget.token,
          initialIndex: 2,
          showPaymentSuccess: false, // Don't show success message
        ),
      ),
    );
  }

  Future<void> addNewAddressDialog(LatLng latlng, String address) async {
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
                          await fetchSavedAddresses();
                          // Auto-select the newly added address
                          await _autoSelectRecentAddress();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Multi-Car Order',
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
        child: Column(
          children: [
            // Main content with bottom padding for fixed button
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    20, 20, 20, 100), // Extra bottom padding for fixed button
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address Section
                    _buildAddressSection(),
                    const SizedBox(height: 28),

                    // Package Section
                    if (userPackage != null) ...[
                      _buildPackageSection(),
                      const SizedBox(height: 28),
                    ],

                    // Cars Section
                    _buildCarsSection(),
                    const SizedBox(height: 28),

                    // Schedule Section
                    _buildScheduleSection(),
                    const SizedBox(height: 28),

                    // Order Summary
                    _buildOrderSummary(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Fixed Payment Button at bottom
            _buildFixedPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Address'),
        if (isLoadingAddresses)
          const Center(child: CircularProgressIndicator()),
        if (!isLoadingAddresses && savedAddresses.isNotEmpty)
          ...savedAddresses.map((addr) => Card(
                color: selectedSavedAddress != null &&
                        selectedSavedAddress!['id'] == addr['id']
                    ? Colors.green[50]
                    : Colors.white,
                child: ListTile(
                  title: Text(addr['label'] ?? addr['address'] ?? 'Address',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${addr['street'] ?? ''} ${addr['building'] ?? ''} ${addr['floor'] ?? ''} ${addr['apartment'] ?? ''}\n${addr['address'] ?? ''}',
                      style: const TextStyle(fontSize: 13)),
                  trailing: selectedSavedAddress != null &&
                          selectedSavedAddress!['id'] == addr['id']
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      selectedSavedAddress = addr;
                      selectedLocation = LatLng(
                        double.parse(addr['latitude'].toString()),
                        double.parse(addr['longitude'].toString()),
                      );
                      selectedAddress = addr['address'];
                    });
                    debugPrint(
                        'Selected saved address: ${addr['label']} - ${addr['address']}');
                    debugPrint(
                        'Address details: street=${addr['street']}, building=${addr['building']}, floor=${addr['floor']}, apartment=${addr['apartment']}');
                  },
                ),
              )),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Add New Address'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () async {
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

              debugPrint(
                  '🗺️ Opening map picker with location: $latitude, $longitude');
              final picked = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapPickerWithSearchScreen(
                    initialLocation:
                        selectedLocation ?? LatLng(latitude!, longitude!),
                  ),
                ),
              );
              if (picked != null &&
                  picked is Map &&
                  picked['latlng'] != null &&
                  picked['address'] != null) {
                await addNewAddressDialog(picked['latlng'], picked['address']);
              }
            } catch (e) {
              debugPrint('❌ Error opening map picker: $e');
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
    );
  }

  Widget _buildPackageSection() {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.black),
                const SizedBox(width: 8),
                Text(
                  'Current Package',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${userPackage!['package']['name']} - ${userPackage!['remaining_points']} points remaining',
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: usePackage,
                  onChanged: togglePackageUsage,
                  activeColor: Colors.black,
                ),
                const Text('Use Package',
                    style: TextStyle(color: Colors.black)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Selected Cars (${selectedCars.length})'),
            if (selectedCars.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    selectedCars.clear();
                    calculateTotalPrice();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ All cars cleared'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                icon: Icon(Icons.clear_all, size: 16),
                label: Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: addCarToOrder,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                    'Add Car (${cars.length - selectedCars.length} available)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...selectedCars.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> carData = entry.value;
          return _buildCarCard(carData, index);
        }),
      ],
    );
  }

  Widget _buildCarCard(Map<String, dynamic> carData, int index) {
    final car = cars.firstWhere((c) => c['id'] == carData['car_id']);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${car['brand']['name']} ${car['model']['name']}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit),
                          const SizedBox(width: 8),
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.black),
                          const SizedBox(width: 8),
                          const Text('Delete',
                              style: TextStyle(color: Colors.black)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      editCarServices(index);
                    } else if (value == 'delete') {
                      removeCarFromOrder(index);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Year: ${car['year']['year']} • Color: ${car['color']}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Selected Services:',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (carData['services'] as List).map<Widget>((serviceId) {
                final service =
                    services.firstWhere((s) => s['id'] == serviceId);
                return Chip(
                  label: Text(service['name']),
                  backgroundColor: Colors.grey.shade200,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  usePackage ? 'Points Used:' : 'Total:',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Builder(
                  builder: (context) {
                    final pointsUsed = carData['points_used'] ?? 0;
                    debugPrint(
                        'Displaying car ${carData['car_id']} with $pointsUsed points (usePackage: $usePackage)');
                    return Text(
                      usePackage
                          ? '$pointsUsed Points'
                          : '${(carData['subtotal'] ?? 0).toStringAsFixed(2)} AED',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Schedule'),
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
          child: ElevatedButton.icon(
            onPressed: _showTimeSlotDialog,
            icon: Icon(
                selectedDateTime != null ? Icons.access_time : Icons.schedule),
            label: Text(
              selectedDateTime != null
                  ? 'Selected: ${_formatSelectedTime(selectedDateTime!)}'
                  : 'Select Time Slot',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor:
                  selectedDateTime != null ? Colors.green : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
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
    debugPrint('🔄 Refreshing booked time slots before showing dialog');
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
                          'Select Date & Time',
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
                                    'Select Date',
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
                                      'Today',
                                      DateTime.now(),
                                      setDialogState,
                                      Icons.today),
                                  const SizedBox(height: 6),
                                  _buildModernDateOption(
                                      'Tomorrow',
                                      DateTime.now()
                                          .add(const Duration(days: 1)),
                                      setDialogState,
                                      Icons.event_available),
                                  const SizedBox(height: 6),
                                  _buildModernDateOption(
                                      'Day After',
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
                                    'Select Time',
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

                                    return GestureDetector(
                                      onTap: (isBooked || isUnavailable)
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
                                                  : (isSelected
                                                      ? Colors.green.shade600
                                                      : Colors.white),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isBooked
                                                ? Colors.red.shade300
                                                : isUnavailable
                                                    ? Colors.orange.shade300
                                                    : (isSelected
                                                        ? Colors.green.shade600
                                                        : Colors.grey.shade300),
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
                                                            : (isSelected
                                                                ? Colors.white
                                                                : Colors.grey
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
                                                  isUnavailable) ...[
                                                const SizedBox(height: 2),
                                                Flexible(
                                                  child: Text(
                                                    'OFF',
                                                    style: GoogleFonts.poppins(
                                                      color: isBooked
                                                          ? Colors.red.shade600
                                                          : Colors
                                                              .orange.shade600,
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

    for (int hour = 10; hour <= 23; hour++) {
      String period = hour < 12 ? 'AM' : 'PM';
      int displayHour = hour > 12 ? hour - 12 : hour;
      if (hour == 12) displayHour = 12;

      bool isBooked = bookedHours.contains(hour);
      bool isUnavailable = unavailableHours.contains(hour);

      timeSlots.add({
        'hour': hour,
        'displayHour': displayHour,
        'period': period,
        'label': '${displayHour}:00 ${period}',
        'datetime': selectedDate.copyWith(
            hour: hour, minute: 0, second: 0, millisecond: 0),
        'isBooked': isBooked,
        'isUnavailable': isUnavailable,
      });
    }

    return timeSlots;
  }

  // Helper function to check if two dates are the same day
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
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
                'Time Slot Selected!',
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
      return 'Today - ${date.day}/${date.month}';
    } else if (targetDate == tomorrow) {
      return 'Tomorrow - ${date.day}/${date.month}';
    } else if (targetDate == dayAfter) {
      return 'Day After - ${date.day}/${date.month}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Helper function to build date option button
  Widget _buildDateOption(
      String label, DateTime date, StateSetter setDialogState) {
    final isSelected = _isSameDate(selectedDate, date);
    final isToday = _isSameDate(date, DateTime.now());
    final isTomorrow =
        _isSameDate(date, DateTime.now().add(const Duration(days: 1)));

    String displayLabel = label;
    if (isToday)
      displayLabel = 'Today';
    else if (isTomorrow)
      displayLabel = 'Tomorrow';
    else
      displayLabel = 'Day After';

    return GestureDetector(
      onTap: () async {
        // Prevent multiple taps on the same date or during loading
        if (_isSameDate(selectedDate, date) || isChangingDate) return;

        setDialogState(() {
          isChangingDate = true;
          selectedDate = date;
          selectedDateTime = null; // Reset time selection when date changes
        });

        // Fetch time slots for the new date
        await _fetchBookedTimeSlots(date);

        setDialogState(() {
          isChangingDate = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.blue.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(
              displayLabel,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.blue.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${date.day}/${date.month}',
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.blue.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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

  String _formatSelectedTime(DateTime dateTime) {
    String period = dateTime.hour < 12 ? 'AM' : 'PM';
    int displayHour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    if (dateTime.hour == 12) displayHour = 12;

    String dateLabel = '';
    if (_isSameDate(dateTime, DateTime.now())) {
      dateLabel = 'Today';
    } else if (_isSameDate(
        dateTime, DateTime.now().add(const Duration(days: 1)))) {
      dateLabel = 'Tomorrow';
    } else if (_isSameDate(
        dateTime, DateTime.now().add(const Duration(days: 2)))) {
      dateLabel = 'Day After';
    } else {
      dateLabel = '${dateTime.day}/${dateTime.month}';
    }

    return '$dateLabel - ${displayHour}:00 $period';
  }

  Widget _buildOrderSummary() {
    int totalPointsUsed = 0;
    if (usePackage) {
      for (var car in selectedCars) {
        final carPoints = (car['points_used'] as int?) ?? 0;
        totalPointsUsed += carPoints;
        debugPrint('Car ${car['car_id']} points: $carPoints');
      }
      debugPrint('Total points used: $totalPointsUsed');
    }

    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Number of Cars:'),
                Text('${selectedCars.length}'),
              ],
            ),
            const SizedBox(height: 8),
            if (usePackage) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Points Used:'),
                  Text('$totalPointsUsed Points'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Points Remaining:'),
                  Text(
                      '${(userPackage?['remaining_points'] ?? 0) - totalPointsUsed} Points'),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${totalPrice.toStringAsFixed(2)} AED',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFixedPaymentButton() {
    final bool isReadyToProceed = selectedCars.isNotEmpty &&
        selectedDateTime != null &&
        selectedLocation != null &&
        selectedSavedAddress != null;

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
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              // Price Display
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Amount',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          usePackage
                              ? 'FREE'
                              : 'AED ${totalPrice.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: usePackage
                                ? Colors.green.shade700
                                : Colors.black,
                          ),
                        ),
                        if (usePackage) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Package',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
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

              const SizedBox(width: 16),

              // Payment Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isReadyToProceed
                      ? [
                          BoxShadow(
                            color: (usePackage ? Colors.green : Colors.black)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: isReadyToProceed
                      ? () {
                          // Add haptic feedback
                          HapticFeedback.mediumImpact();
                          submitMultiCarOrder();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReadyToProceed
                        ? (usePackage ? Colors.green.shade600 : Colors.black)
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    minimumSize: const Size(140, 56),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        usePackage ? Icons.card_giftcard : Icons.payment,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        usePackage ? 'Use Package' : 'Pay Now',
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
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      );
}

// Dialog for car and services selection
class CarSelectionDialog extends StatefulWidget {
  final List cars;
  final List services;
  final bool usePackage;
  final List<dynamic> availableServices;
  final Function(Map<String, dynamic>) onCarAdded;
  final Map<String, dynamic>? initialCarData;
  final String token;
  final VoidCallback? onCarsUpdated;

  const CarSelectionDialog({
    super.key,
    required this.cars,
    required this.services,
    required this.usePackage,
    required this.availableServices,
    required this.onCarAdded,
    required this.token,
    this.initialCarData,
    this.onCarsUpdated,
  });

  @override
  State<CarSelectionDialog> createState() => _CarSelectionDialogState();
}

class _CarSelectionDialogState extends State<CarSelectionDialog> {
  int? selectedCarId;
  List<int> selectedServices = [];
  double subtotal = 0;
  int pointsUsed = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('CarSelectionDialog initState started');

    try {
      if (widget.initialCarData != null) {
        selectedCarId = widget.initialCarData!['car_id'];
        selectedServices =
            List<int>.from(widget.initialCarData!['services'] ?? []);
        subtotal = (widget.initialCarData!['subtotal'] as double?) ?? 0.0;

        // Recalculate points based on current available services
        pointsUsed = 0;
        if (widget.usePackage) {
          for (var serviceId in selectedServices) {
            final points = PackageService.getPointsRequiredForService(
                widget.availableServices, serviceId);
            pointsUsed += points;
          }
        } else {
          pointsUsed = (widget.initialCarData!['points_used'] as int?) ?? 0;
        }
      }

      debugPrint('CarSelectionDialog initState completed successfully');
    } catch (e) {
      debugPrint('Error in CarSelectionDialog initState: $e');
    }
  }

  void toggleService(int serviceId, double price, int points) {
    debugPrint(
        'Toggling service $serviceId with $points points (usePackage: ${widget.usePackage})');
    setState(() {
      if (selectedServices.contains(serviceId)) {
        selectedServices.remove(serviceId);
        if (!widget.usePackage) {
          subtotal -= price;
        } else {
          pointsUsed -= points;
        }
        debugPrint('Removed service $serviceId - pointsUsed: $pointsUsed');
      } else {
        selectedServices.add(serviceId);
        if (!widget.usePackage) {
          subtotal += price;
        } else {
          pointsUsed += points;
        }
        debugPrint('Added service $serviceId - pointsUsed: $pointsUsed');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building CarSelectionDialog');

    try {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initialCarData != null ? 'Edit Car' : 'Add Car',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Car:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...widget.cars
                          .where((car) => car != null && car['id'] != null)
                          .map((car) => RadioListTile<int>(
                                value: car['id'],
                                groupValue: selectedCarId,
                                title: Text(
                                    '${car['brand']?['name'] ?? 'Unknown'} ${car['model']?['name'] ?? 'Unknown'}'),
                                subtitle: Text(
                                    '${car['year']?['year'] ?? 'Unknown'} • ${car['color'] ?? 'Unknown'}'),
                                onChanged: (val) =>
                                    setState(() => selectedCarId = val),
                                activeColor: Colors.black,
                              )),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline,
                            color: Colors.blue),
                        title: Text(
                          'Add New Car',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        subtitle: const Text(
                            'Create a new car to add to your collection'),
                        onTap: () async {
                          Navigator.pop(context);
                          final added = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddCarScreen(token: widget.token),
                            ),
                          );
                          if (added == true) {
                            // Refresh cars list
                            widget.onCarsUpdated?.call();
                            // Show success message - check if widget is still mounted
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      '✅ Car added successfully! Please select it from the list.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Select Services:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.services.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Loading services...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ...widget.services
                          .where((service) =>
                              service != null && service['id'] != null)
                          .map((service) {
                        final price =
                            double.tryParse(service['price'].toString()) ?? 0.0;

                        // Use same logic as main order screen
                        final isAvailableInPackage = widget.usePackage &&
                            PackageService.isServiceAvailableInPackage(
                                widget.availableServices, service['id']);
                        final pointsRequired =
                            widget.usePackage && isAvailableInPackage
                                ? PackageService.getPointsRequiredForService(
                                    widget.availableServices, service['id'])
                                : 0;

                        debugPrint(
                            'Service ${'${service['name']}'}: available=$isAvailableInPackage, points=$pointsRequired');

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: selectedServices.contains(service['id'])
                                ? Colors.grey.shade100
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedServices.contains(service['id'])
                                  ? Colors.black
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: selectedServices.contains(service['id']),
                            onChanged: (val) {
                              toggleService(
                                  service['id'], price, pointsRequired);
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Text(
                              service['name'] ?? 'Unknown Service',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: service['description'] != null &&
                                    service['description'].toString().isNotEmpty
                                ? Text(
                                    service['description'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            secondary: widget.usePackage && isAvailableInPackage
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${pointsRequired} Points',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : Text(
                                    '${price.toStringAsFixed(0)} AED',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                            activeColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.usePackage ? 'Points Used:' : 'Total:',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.usePackage
                              ? '$pointsUsed Points'
                              : '${subtotal.toStringAsFixed(2)} AED',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            selectedCarId != null && selectedServices.isNotEmpty
                                ? () {
                                    debugPrint('Adding car with data:');
                                    debugPrint('car_id: $selectedCarId');
                                    debugPrint('services: $selectedServices');
                                    debugPrint('subtotal: $subtotal');
                                    debugPrint('points_used: $pointsUsed');

                                    widget.onCarAdded({
                                      'car_id': selectedCarId!,
                                      'services': selectedServices,
                                      'subtotal': subtotal,
                                      'points_used': pointsUsed,
                                    });
                                    Navigator.pop(context);
                                  }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.initialCarData != null ? 'Update' : 'Add',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
      );
    } catch (e) {
      debugPrint('Error building CarSelectionDialog: $e');
      return Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Error loading car selection dialog'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
