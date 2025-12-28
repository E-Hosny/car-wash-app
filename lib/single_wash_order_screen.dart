import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_car_screen.dart';
import 'map_picker_with_search_screen.dart';
import 'payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/package_service.dart';
import 'utils/debug_helper.dart';
import 'main_navigation_screen.dart';
import 'services/config_service.dart';
import 'services/cache_service.dart';
import 'order_confirmation_screen.dart';
import 'widgets/animated_loading_indicator.dart';

class SingleWashOrderScreen extends StatefulWidget {
  final String token;
  final bool? initialUsePackage;
  final int? preselectedServiceId;

  const SingleWashOrderScreen({
    super.key,
    required this.token,
    this.initialUsePackage,
    this.preselectedServiceId,
  });

  @override
  State<SingleWashOrderScreen> createState() => _SingleWashOrderScreenState();
}

class _SingleWashOrderScreenState extends State<SingleWashOrderScreen>
    with TickerProviderStateMixin {
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

  DateTime? selectedDateTime;
  DateTime selectedDate =
      DateTime.now(); // التاريخ المختار (اليوم، الغد، بعد الغد)

  bool isMapInteracting = false;
  bool isSubmittingOrder = false;

  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, dynamic>? selectedSavedAddress;
  bool isLoadingAddresses = false;
  bool packagesEnabled = true;

  // Booked time slots
  List<int> bookedHours = [];
  List<int> unavailableHours = [];
  bool isLoadingTimeSlots = false;
  bool isChangingDate = false; // Flag to prevent multiple date changes

  // Track if user has explicitly selected an address
  bool hasSelectedAddress = false;

  bool isLoading = true;
  bool isRefreshing = false;
  String? errorMessage;
  
  // Track expanded descriptions for each service
  Map<int, bool> expandedServices = {};

  // Loading animation controller
  late AnimationController _loadingAnimationController;
  late Animation<double> _loadingScaleAnimation;
  late Animation<double> _loadingOpacityAnimation;

  @override
  void initState() {
    super.initState();
    print('🚀 SingleWashOrderScreen initState started');
    
    // Initialize loading animation
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _loadingScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _loadingOpacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _initializeData();
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Load configuration first
      packagesEnabled = await ConfigService.fetchPackagesEnabled();

      // If initialUsePackage is true, prioritize loading package and available services
      if (widget.initialUsePackage == true && packagesEnabled) {
        // Load services first (needed for preselected service)
        await _fetchServices();
        
        // Load package and available services
        await _checkUserPackage();
        // _checkUserPackage will call _fetchAvailableServices which will set isLoading = false
        // Load other data in background
        _loadOtherDataInBackground();
        return; // Exit early, _fetchAvailableServices will handle isLoading
      }

      // Try to load from cache first for instant display (synchronous, no API call)
      // Use even expired cache for instant display - better UX
      final cacheService = CacheService();
      bool hasCachedData = false;

      // First try valid cache
      var cachedServices = cacheService.getCachedServices(widget.token);
      var cachedCars = cacheService.getCachedCars(widget.token);
      var cachedAddresses = cacheService.getCachedAddresses(widget.token);
      var cachedTimeSlots = cacheService.getCachedTimeSlots(widget.token, selectedDate);

      // If no valid cache, try expired cache for instant display
      if (cachedServices == null || cachedServices.isEmpty) {
        cachedServices = cacheService.getCachedServicesEvenExpired(widget.token);
      }
      if (cachedCars == null || cachedCars.isEmpty) {
        cachedCars = cacheService.getCachedCarsEvenExpired(widget.token);
      }
      if (cachedAddresses == null || cachedAddresses.isEmpty) {
        cachedAddresses = cacheService.getCachedAddressesEvenExpired(widget.token);
      }
      if (cachedTimeSlots == null) {
        cachedTimeSlots = cacheService.getCachedTimeSlotsEvenExpired(widget.token, selectedDate);
      }

      // Load any available cached data immediately (even if expired) for instant display
      if (cachedServices != null && cachedServices.isNotEmpty ||
          cachedCars != null && cachedCars.isNotEmpty ||
          cachedAddresses != null && cachedAddresses.isNotEmpty ||
          cachedTimeSlots != null) {
        // Load cached data immediately (synchronous)
        if (cachedServices != null && cachedServices.isNotEmpty) {
          setState(() {
            services = List<dynamic>.from(cachedServices!);
          });
        }
        if (cachedCars != null && cachedCars.isNotEmpty) {
          setState(() {
            cars = List<dynamic>.from(cachedCars!);
          });
        }
        if (cachedAddresses != null && cachedAddresses.isNotEmpty) {
          setState(() {
            savedAddresses = List<Map<String, dynamic>>.from(cachedAddresses!);
            isLoadingAddresses = false;
          });
        }
        if (cachedTimeSlots != null) {
          final timeSlots = cachedTimeSlots;
          setState(() {
            bookedHours = List<int>.from(timeSlots['booked_hours'] ?? []);
            unavailableHours =
                List<int>.from(timeSlots['unavailable_hours'] ?? []);
            isLoadingTimeSlots = false;
          });
        }

        // Auto-select most recent car and address from cached data
        await _autoSelectRecentData();

        // Hide loading indicator immediately if we have cached data
        setState(() {
          isLoading = false;
        });
        hasCachedData = true;

        print(
            '📦 Loaded data from cache instantly (may include expired cache), refreshing in background...');
      }

      // Check if we need to refresh each data type (check valid cache, not expired)
      final validCachedServices = cacheService.getCachedServices(widget.token);
      final validCachedCars = cacheService.getCachedCars(widget.token);
      final validCachedAddresses = cacheService.getCachedAddresses(widget.token);
      final validCachedTimeSlots = cacheService.getCachedTimeSlots(widget.token, selectedDate);

      // Only refresh data in background if valid cache is expired or missing
      bool needRefreshServices = validCachedServices == null || validCachedServices.isEmpty;
      bool needRefreshCars = validCachedCars == null || validCachedCars.isEmpty;
      bool needRefreshAddresses = validCachedAddresses == null || validCachedAddresses.isEmpty;
      bool needRefreshTimeSlots = validCachedTimeSlots == null;

      List<Future> refreshTasks = [];

      if (needRefreshServices) refreshTasks.add(_fetchServices());
      if (needRefreshCars) refreshTasks.add(_fetchUserCars());
      if (needRefreshAddresses) refreshTasks.add(_fetchSavedAddresses());
      if (needRefreshTimeSlots) refreshTasks.add(_fetchBookedTimeSlots());

      // Always fetch location and package info
      refreshTasks.add(_determineCurrentPosition());
      if (packagesEnabled) refreshTasks.add(_checkUserPackage());

      // Refresh only what's needed in background
      if (refreshTasks.isNotEmpty) {
        Future.wait(refreshTasks).then((_) {
          // Update selection with fresh data if needed
          if (hasCachedData) {
            _autoSelectRecentData();
          }
        }).catchError((e) {
          print('⚠️ Error refreshing data in background: $e');
        });
      } else {
        print('✅ All data is fresh from cache, no refresh needed');
      }

      // If no cached data, wait for API calls
      if (!hasCachedData) {
        await Future.wait([
          _fetchServices(),
          _fetchUserCars(),
          _determineCurrentPosition(),
          _fetchSavedAddresses(),
          _fetchBookedTimeSlots(),
          if (packagesEnabled) _checkUserPackage(),
        ]);

        // Auto-select most recent car and address with fresh data
        await _autoSelectRecentData();

        setState(() {
          isLoading = false;
        });
      }

      print('✅ SingleWashOrderScreen initialization completed successfully');
    } catch (e) {
      print('❌ Error in SingleWashOrderScreen initialization: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data. Please try again.';
      });
    }
  }

  // Helper method to load other data in background when package is prioritized
  Future<void> _loadOtherDataInBackground() async {
    try {
      final cacheService = CacheService();
      final cachedServices = cacheService.getCachedServices(widget.token);
      final cachedCars = cacheService.getCachedCars(widget.token);
      final cachedAddresses = cacheService.getCachedAddresses(widget.token);
      final cachedTimeSlots =
          cacheService.getCachedTimeSlots(widget.token, selectedDate);

      // Load cached data if available
      if (cachedServices != null && cachedServices.isNotEmpty) {
        setState(() {
          services = cachedServices;
        });
      }
      if (cachedCars != null && cachedCars.isNotEmpty) {
        setState(() {
          cars = cachedCars;
        });
      }
      if (cachedAddresses != null && cachedAddresses.isNotEmpty) {
        setState(() {
          savedAddresses = cachedAddresses;
          isLoadingAddresses = false;
        });
      }
      if (cachedTimeSlots != null) {
        setState(() {
          bookedHours = List<int>.from(cachedTimeSlots['booked_hours'] ?? []);
          unavailableHours =
              List<int>.from(cachedTimeSlots['unavailable_hours'] ?? []);
          isLoadingTimeSlots = false;
        });
      }

      // Auto-select most recent car and address
      await _autoSelectRecentData();

      // Refresh other data in background
      List<Future> refreshTasks = [];
      if (cachedServices == null) refreshTasks.add(_fetchServices());
      if (cachedCars == null) refreshTasks.add(_fetchUserCars());
      if (cachedAddresses == null) refreshTasks.add(_fetchSavedAddresses());
      if (cachedTimeSlots == null) refreshTasks.add(_fetchBookedTimeSlots());
      refreshTasks.add(_determineCurrentPosition());

      if (refreshTasks.isNotEmpty) {
        Future.wait(refreshTasks).then((_) {
          _autoSelectRecentData();
        }).catchError((e) {
          print('⚠️ Error refreshing data in background: $e');
        });
      }
    } catch (e) {
      print('⚠️ Error loading other data in background: $e');
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
      final cacheService = CacheService();
      final servicesData = await cacheService.getServices(widget.token);

      if (!mounted) return;
      
      // Debug: Print image_url for each service
      for (var service in servicesData) {
        print('📋 Service: ${service['name']}, image_url: ${service['image_url']}');
      }
      
      setState(() {
        services = servicesData;
      });
      DebugHelper.logServiceData(services);
    } catch (e) {
      print('Error fetching services: $e');
      if (!mounted) return;
      setState(() {
        services = [];
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
      if (!mounted) return;
      setState(() {
        cars = [];
      });
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

  Future<void> _fetchBookedTimeSlots([DateTime? date]) async {
    final targetDate = date ?? selectedDate;

    // Try to load from cache first (synchronous)
    final cacheService = CacheService();
    final cachedTimeSlots =
        cacheService.getCachedTimeSlots(widget.token, targetDate);

    if (cachedTimeSlots != null) {
      // Load from cache immediately
      setState(() {
        bookedHours = List<int>.from(cachedTimeSlots['booked_hours'] ?? []);
        unavailableHours =
            List<int>.from(cachedTimeSlots['unavailable_hours'] ?? []);
        isLoadingTimeSlots = false;
      });
      print(
          '📦 Loaded time slots from cache for date: ${targetDate.toIso8601String().split('T')[0]}');

      // Refresh in background
      _refreshTimeSlotsInBackground(targetDate);
      return;
    }

    // No cache, fetch from API
    setState(() => isLoadingTimeSlots = true);
    try {
      final timeSlotsData =
          await cacheService.getBookedTimeSlots(widget.token, targetDate);

      if (!mounted) return;
      setState(() {
        bookedHours = List<int>.from(timeSlotsData['booked_hours'] ?? []);
        unavailableHours =
            List<int>.from(timeSlotsData['unavailable_hours'] ?? []);
        isLoadingTimeSlots = false;
      });
      print('📅 Booked hours loaded: $bookedHours');
      print('🚫 Unavailable hours loaded: $unavailableHours');
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

  Future<void> _refreshTimeSlotsInBackground(DateTime date) async {
    try {
      final cacheService = CacheService();
      final timeSlotsData =
          await cacheService.getBookedTimeSlots(widget.token, date);

      if (!mounted) return;
      setState(() {
        bookedHours = List<int>.from(timeSlotsData['booked_hours'] ?? []);
        unavailableHours =
            List<int>.from(timeSlotsData['unavailable_hours'] ?? []);
      });
      print('🔄 Time slots refreshed in background');
    } catch (e) {
      print('⚠️ Error refreshing time slots in background: $e');
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
        
        // If initialUsePackage is true, wait for available services to load
        if (widget.initialUsePackage == true) {
          await _fetchAvailableServices();
        } else {
          _fetchAvailableServices();
        }
      } else {
        // If no package found and initialUsePackage is true, set loading to false
        if (widget.initialUsePackage == true) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error checking user package: $e');
      // If initialUsePackage is true and error occurred, set loading to false
      if (widget.initialUsePackage == true) {
        setState(() {
          isLoading = false;
        });
      }
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
        
        // Auto-enable package usage if requested
        if (widget.initialUsePackage == true && userPackage != null) {
          setState(() {
            usePackage = true;
            totalPrice = 0;
          });
          
          // Auto-select preselected service if provided
          if (widget.preselectedServiceId != null) {
            final serviceId = widget.preselectedServiceId!;
            // Check if service is available in package
            // availableServices uses 'id' field (which is service_id)
            final isAvailable = availableServices.any((s) => 
              s['id'] == serviceId && 
              (s['remaining_quantity'] ?? 0) > 0
            );
            
            if (isAvailable && !selectedServices.contains(serviceId)) {
              // Find service price - need to load services first if not loaded
              try {
                // Try to find service in current services list
                final service = services.firstWhere(
                  (s) => s['id'] == serviceId,
                  orElse: () => {},
                );
                if (service.isNotEmpty) {
                  final price = double.tryParse(service['price'].toString()) ?? 0.0;
                  _toggleService(serviceId, price, true);
                }
              } catch (e) {
                print('Error selecting preselected service: $e');
              }
            }
          }
          
          // Set isLoading to false after loading available services
          setState(() {
            isLoading = false;
          });
          
          // Load other data in background
          _loadOtherDataInBackground();
        }
      } else {
        // If failed to fetch and initialUsePackage is true, set loading to false
        if (widget.initialUsePackage == true) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching available services: $e');
      // If error occurred and initialUsePackage is true, set loading to false
      if (widget.initialUsePackage == true) {
        setState(() {
          isLoading = false;
        });
      }
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

  String _getPackageServicesText(Map<String, dynamic> userPackage) {
    final services = userPackage['services'] as List? ?? [];
    int totalRemaining = 0;
    
    for (var service in services) {
      final remaining = service['remaining_quantity'] ?? 0;
      totalRemaining += remaining is int ? remaining : (remaining is String ? int.tryParse(remaining) ?? 0 : 0);
    }
    
    final packageName = userPackage['package']['name'] ?? 'Package';
    return '$packageName - $totalRemaining services remaining';
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
        !hasSelectedAddress ||
        selectedDateTime == null) {
      _showErrorDialog(
        'Missing Information',
        'Please select at least one service, car, address, and time slot to continue.',
        Icons.warning_amber_rounded,
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
        'scheduled_at': selectedDateTime?.toIso8601String(),
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
        // Invalidate orders cache to ensure fresh data
        final cacheService = CacheService();
        cacheService.invalidateOrders(widget.token);
        
        // Show success animation before navigating
        await _showOrderSuccessAnimation();
        // Navigate to orders screen directly - no need to reload data
        _navigateToOrders();
      } else if (result == false) {
        // Payment failed or was cancelled - show error message
        _showErrorDialog(
          'Payment Failed',
          'Your order was not created due to payment failure. Please try again.',
          Icons.payment,
        );
      }
      // If result is null, user just pressed back button - no action needed
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
          initialIndex: 2, // Orders tab
          showPaymentSuccess: false, // Don't show success message
        ),
      ),
    );
  }

  // Show order confirmation dialog
  Future<bool> _showOrderConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50,
                    Colors.blue.shade100,
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
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.shopping_cart_checkout,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Confirm Order',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Message
                  Text(
                    'Are you ready to proceed with your car wash order?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Order summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Services:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              '${selectedServices.length} selected',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount:',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              'AED ${totalPrice.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade600,
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
                          onPressed: () => Navigator.pop(context, false),
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
                            Navigator.pop(context, true);
                            // Reload page data after confirmation
                            await _reloadPageData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            'Proceed',
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
        ) ??
        false;
  }

  // Show error dialog
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
              // Icon
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
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Reload page data after dismissing error
                    await _reloadPageData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
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

  // Show order success animation
  Future<void> _showOrderSuccessAnimation() async {
    // Play haptic feedback
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Your car wash order has been confirmed and payment processed.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Loading indicator
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto close after 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Reload page data after any confirmation
  Future<void> _reloadPageData() async {
    try {
      // Show loading indicator
      if (mounted) {
        setState(() {
          isRefreshing = true;
        });
      }

      // Reload all data
      await Future.wait([
        _fetchAvailableServices(),
        _fetchBookedTimeSlots(),
        _fetchUserCars(),
        _fetchSavedAddresses(),
      ]);

      // Hide loading indicator
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }
    } catch (e) {
      print('Error reloading page data: $e');

      // Hide loading indicator
      if (mounted) {
        setState(() {
          isRefreshing = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Failed to refresh data. Please try again.',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 20,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
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
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 24,
                        ),
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

                // Form fields
                _buildModernTextField(
                  controller: labelController,
                  label: 'Label',
                  hint: 'e.g. Home, Work',
                  icon: Icons.label,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: streetController,
                  label: 'Street',
                  hint: 'Enter street name',
                  icon: Icons.route,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: buildingController,
                  label: 'Building',
                  hint: 'Enter building name/number',
                  icon: Icons.business,
                ),
                const SizedBox(height: 16),
                _buildModernTextField(
                  controller: notesController,
                  label: 'Notes',
                  hint: 'Additional instructions (optional)',
                  icon: Icons.note,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Location display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.place,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
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

                // Action buttons
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
                                    // Invalidate cache and fetch fresh data
                                    CacheService()
                                        .invalidateAddresses(widget.token);
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
                                          content:
                                              Text('Failed to save address'),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Error saving address: ${e.toString()}'),
                                        backgroundColor: Colors.red),
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
                          elevation: 2,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          label: isRequired
              ? RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: label),
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.blue.shade600,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
          ),
          labelStyle: isRequired
              ? GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                )
              : GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  // Calculate total services used for selected services
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

      final remaining = PackageService.getRemainingQuantityForService(
        availableServices,
        serviceId,
      );
      if (remaining > 0) {
        totalPoints += 1; // Each service uses 1 quantity
      }
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated loading indicator with pulsing effect
              AnimatedBuilder(
                animation: _loadingAnimationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _loadingScaleAnimation.value,
                    child: Opacity(
                      opacity: _loadingOpacityAnimation.value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.black,
                              Colors.grey.shade800,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Loading your preferences...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              // Animated dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _loadingAnimationController,
                    builder: (context, child) {
                      final delay = index * 0.2;
                      final animationValue = (_loadingAnimationController.value + delay) % 1.0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade400.withOpacity(
                            0.3 + (animationValue * 0.7),
                          ),
                        ),
                      );
                    },
                  );
                }),
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
      body: Stack(
        children: [
          Container(
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
                  child: RefreshIndicator(
                    onRefresh: _reloadPageData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          20, 20, 20, 100), // Extra bottom padding for fixed button
                      physics: isMapInteracting
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Services Selection Only
                          _buildServicesSection(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Fixed Confirm Button at bottom
                _buildFixedConfirmButton(),
              ],
            ),
          ),
          // Show AnimatedLoadingIndicator when refreshing
          if (isRefreshing)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const AnimatedLoadingIndicator(
                message: 'Refreshing Data...',
              ),
            ),
        ],
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
                        // Invalidate cache and fetch fresh data
                        CacheService().invalidateCars(widget.token);
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
    // Filter services based on package availability
    List<dynamic> servicesToShow = services;
    if (usePackage && availableServices.isNotEmpty) {
      // Only show services that are available in the package
      final availableServiceIds = availableServices
          .where((s) => (s['remaining_quantity'] ?? 0) > 0)
          .map((s) => s['id'])
          .toSet();
      servicesToShow = services
          .where((s) => availableServiceIds.contains(s['id']))
          .toList();
    }

    if (servicesToShow.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Services'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                usePackage && availableServices.isEmpty
                    ? 'No services available in your package'
                    : 'No services available',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Services'),
        ...servicesToShow.map((s) {
          final price = double.tryParse(s['price'].toString()) ?? 0.0;
          final isAvailableInPackage = usePackage &&
              availableServices.any((service) => service['id'] == s['id']);
          final remainingQuantity = usePackage && isAvailableInPackage
              ? PackageService.getRemainingQuantityForService(
                  availableServices, s['id'])
              : null;

          final isSelected = selectedServices.contains(s['id']);

          return GestureDetector(
            onTap: () {
              // Add haptic feedback
              HapticFeedback.selectionClick();
              _toggleService(s['id'], price, !isSelected);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.blue.shade100
                        : Colors.grey.shade100,
                    blurRadius: isSelected ? 12 : 6,
                    offset: const Offset(0, 4),
                    spreadRadius: isSelected ? 2 : 0,
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
                          color: isSelected
                              ? Colors.blue.shade300
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Builder(
                          builder: (context) {
                            final imageUrl = s['image_url'];
                            if (imageUrl != null && imageUrl.toString().isNotEmpty) {
                              print('🖼️ Loading image for service ${s['name']}: $imageUrl');
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
                                  print('❌ Error loading image: $url');
                                  print('❌ Error details: $error');
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
                              print('⚠️ No image_url for service ${s['name']}');
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
                          // Service name and price/points
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  s['name'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: isSelected
                                        ? Colors.blue.shade800
                                        : Colors.grey.shade800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Price or points badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: usePackage && isAvailableInPackage
                                      ? Colors.blue.shade600
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: usePackage && isAvailableInPackage
                                      ? null
                                      : Border.all(
                                          color: Colors.green.shade300),
                                ),
                                child: Text(
                                  usePackage && isAvailableInPackage
                                      ? remainingQuantity != null && remainingQuantity > 0
                                          ? '$remainingQuantity remaining'
                                          : 'Not available'
                                      : '${price.toStringAsFixed(0)} AED',
                                  style: GoogleFonts.poppins(
                                    color: usePackage && isAvailableInPackage
                                        ? Colors.white
                                        : Colors.green.shade700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Service description with Read more/Show less
                          if (s['description'] != null &&
                              s['description'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['description'],
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                  maxLines: expandedServices[s['id']] == true ? null : 2,
                                  overflow: expandedServices[s['id']] == true ? null : TextOverflow.ellipsis,
                                ),
                                // Show Read more/Show less button if description is long
                                if (s['description'].toString().length > 100)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        expandedServices[s['id']] = !(expandedServices[s['id']] ?? false);
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        expandedServices[s['id']] == true ? 'Show less' : 'Read more',
                                        style: GoogleFonts.poppins(
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

                    // Selection indicator
                    if (isSelected) ...[
                      const SizedBox(width: 8),
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 20,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
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
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Address',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose from your saved addresses',
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

              // Address list
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: savedAddresses.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved addresses',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add your first address to get started',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: savedAddresses.length,
                        itemBuilder: (context, index) {
                          final addr = savedAddresses[index];
                          final isSelected = selectedSavedAddress != null &&
                              selectedSavedAddress!['id'] == addr['id'];

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue.shade200
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.home,
                                  color: isSelected
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                addr['label'] ?? addr['address'] ?? 'Address',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.blue.shade800
                                      : Colors.grey.shade800,
                                ),
                              ),
                              subtitle: Text(
                                '${addr['street'] ?? ''} ${addr['building'] ?? ''}\n${addr['address'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  selectedSavedAddress = addr;
                                  selectedLocation = LatLng(
                                    double.parse(addr['latitude'].toString()),
                                    double.parse(addr['longitude'].toString()),
                                  );
                                  selectedAddress = addr['address'];
                                  hasSelectedAddress = true;
                                });
                                Navigator.pop(context);
                              },
                              trailing: isSelected
                                  ? Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Add new address button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
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
                          builder: (context) => MapPickerWithSearchScreen(
                            initialLocation: selectedLocation ??
                                LatLng(latitude!, longitude!),
                            token: widget.token,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.add_location_alt, size: 20),
                  label: Text(
                    'Add New Address',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel button
              TextButton(
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
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
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

  void _showTimeSlotDialogNew() async {
    // Refresh booked time slots before showing dialog
    print('🔄 Refreshing booked time slots before showing dialog');
    await _fetchBookedTimeSlots();

    // Generate 14 time slots from 10 AM to 12 PM (midnight)
    List<Map<String, dynamic>> timeSlots = [];

    for (int hour = 10; hour <= 23; hour++) {
      String period = hour < 12 ? 'AM' : 'PM';
      int displayHour = hour > 12 ? hour - 12 : hour;
      if (hour == 12) displayHour = 12;

      bool isBooked = bookedHours.contains(hour);
      print(
          '🕐 Hour $hour (${displayHour}:00 $period) - Booked: $isBooked (bookedHours: $bookedHours)');

      timeSlots.add({
        'hour': hour,
        'displayHour': displayHour,
        'period': period,
        'label': '${displayHour}:00 ${period}',
        'datetime': DateTime.now()
            .copyWith(hour: hour, minute: 0, second: 0, millisecond: 0),
        'isBooked': isBooked,
      });
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Select Time Slot',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: timeSlots.length,
            itemBuilder: (context, index) {
              final slot = timeSlots[index];
              final isSelected = selectedDateTime != null &&
                  selectedDateTime!.hour == slot['hour'];
              final isBooked = slot['isBooked'] as bool;

              print(
                  '🎯 Building slot for hour ${slot['hour']}: isBooked=$isBooked, isSelected=$isSelected');

              return GestureDetector(
                onTap: isBooked
                    ? null
                    : () {
                        print('✅ Selected time slot: ${slot['label']}');
                        setState(() {
                          selectedDateTime = slot['datetime'];
                        });
                        Navigator.pop(context);
                      },
                child: Container(
                  decoration: BoxDecoration(
                    color: isBooked
                        ? Colors.red.shade100
                        : (isSelected ? Colors.black : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBooked
                          ? Colors.red.shade300
                          : (isSelected ? Colors.black : Colors.grey.shade300),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slot['label'],
                          style: GoogleFonts.poppins(
                            color: isBooked
                                ? Colors.red.shade600
                                : (isSelected ? Colors.white : Colors.black),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (isBooked) ...[
                          const SizedBox(height: 2),
                          Text(
                            'OFF',
                            style: GoogleFonts.poppins(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
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
                                                    isPastHour ? 'Past' : 'OFF',
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
                        // Reload page data after confirmation
                        await _reloadPageData();
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
              _getPackageServicesText(userPackage!),
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

  Widget _buildFixedConfirmButton() {
    final bool isReadyToProceed = selectedServices.isNotEmpty;

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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isReadyToProceed
                  ? () {
                      HapticFeedback.mediumImpact();
                      _navigateToConfirmation();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isReadyToProceed
                    ? Colors.black
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: isReadyToProceed ? 4 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToConfirmation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderConfirmationScreen(
          token: widget.token,
          selectedCarId: selectedCarId,
          selectedServices: selectedServices,
          selectedSavedAddress: selectedSavedAddress,
          selectedAddress: selectedAddress,
          selectedLocation: selectedLocation,
          selectedDateTime: selectedDateTime,
          totalPrice: totalPrice,
          usePackage: usePackage,
          userPackage: userPackage,
          availableServices: availableServices,
          cars: cars,
          savedAddresses: savedAddresses,
          services: services,
          selectedDate: selectedDate,
        ),
      ),
    );
  }
}
