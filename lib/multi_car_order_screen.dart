import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'map_picker_screen.dart';
import 'payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/package_service.dart';
import 'main_navigation_screen.dart';

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

  bool useCurrentTime = true;
  DateTime? selectedDateTime;

  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, dynamic>? selectedSavedAddress;
  bool isLoadingAddresses = false;

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
        checkUserPackage(),
      ]);

      // Validate existing selected cars after data is loaded
      _validateSelectedCars();
    } catch (e) {
      debugPrint('Error initializing data: $e');
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
    await Permission.location.request();
    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (!mounted) return;
    setState(() {
      latitude = pos.latitude;
      longitude = pos.longitude;
      selectedLocation = LatLng(latitude!, longitude!);
    });
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
    if (selectedCars.isEmpty || selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select location and add at least one car'),
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
    debugPrint('useCurrentTime: $useCurrentTime');
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
      'scheduled_at':
          useCurrentTime ? null : selectedDateTime?.toIso8601String(),
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
            content: Text('Payment was not completed. Please try again.'),
            backgroundColor: Colors.orange,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 16),

              const SizedBox(height: 24),
            ],
          ),
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
            if (latitude == null || longitude == null) return;
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
              await addNewAddressDialog(picked['latlng'], picked['address']);
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
        SwitchListTile(
          title: const Text('Request Now', style: TextStyle(fontSize: 16)),
          value: useCurrentTime,
          onChanged: (val) {
            setState(() {
              useCurrentTime = val;
              if (val) selectedDateTime = null;
            });
          },
        ),
        if (!useCurrentTime)
          ElevatedButton(
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
                  : 'Schedule for Later',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
      ],
    );
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

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
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
        onPressed: selectedCars.isNotEmpty ? submitMultiCarOrder : null,
        icon: Icon(usePackage ? Icons.card_giftcard : Icons.payment),
        label: Text(
          usePackage ? 'Use Package Points' : 'Proceed to Payment',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

  const CarSelectionDialog({
    super.key,
    required this.cars,
    required this.services,
    required this.usePackage,
    required this.availableServices,
    required this.onCarAdded,
    this.initialCarData,
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
