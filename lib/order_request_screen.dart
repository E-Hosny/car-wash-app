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
import 'all_packages_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'services/package_service.dart';
import 'utils/debug_helper.dart';
import 'widgets/package_display_card.dart';
import 'widgets/order_summary_card.dart';
import 'widgets/compact_package_card.dart';
import 'widgets/enhanced_package_card.dart';
import 'widgets/package_grid_view.dart';
import 'widgets/optimized_package_card.dart';
import 'main_navigation_screen.dart';
import 'screens/my_package_screen.dart';

class OrderRequestScreen extends StatefulWidget {
  final String token;

  const OrderRequestScreen({super.key, required this.token});

  @override
  State<OrderRequestScreen> createState() => _OrderRequestScreenState();
}

class _OrderRequestScreenState extends State<OrderRequestScreen> {
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

  // إضافة متغيرات للباقات
  List<dynamic> packages = [];
  bool isLoadingPackages = true;
  final PageController _packagePageController = PageController();
  bool showGridView = false; // Toggle between grid and carousel view

  bool useCurrentTime = true;
  DateTime? selectedDateTime;

  bool isMapInteracting = false;
  bool isSubmittingOrder = false;

  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, dynamic>? selectedSavedAddress;
  bool isLoadingAddresses = false;

  @override
  void initState() {
    super.initState();
    fetchServices();
    fetchUserCars();
    determineCurrentPosition();
    fetchSavedAddresses();
    checkUserPackage();
    fetchPackages(); // إضافة جلب الباقات

    // إضافة مستمع لتحديث مؤشرات الصفحات
    _packagePageController.addListener(() {
      setState(() {});
    });
  }

  // إضافة دالة جلب الباقات
  Future<void> fetchPackages() async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        print('Error: BASE_URL not configured');
        setState(() {
          isLoadingPackages = false;
        });
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/packages'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          packages = data['data'] ?? [];
          isLoadingPackages = false;
        });
      } else {
        setState(() {
          isLoadingPackages = false;
        });
      }
    } catch (e) {
      print('Error fetching packages: $e');
      setState(() {
        isLoadingPackages = false;
      });
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
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
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

  Future<void> fetchUserCars() async {
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

  Future<void> fetchSavedAddresses() async {
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

  Future<void> checkUserPackage() async {
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
        fetchAvailableServices();
      }
    } catch (e) {
      print('Error checking user package: $e');
      // Handle error silently
    }
  }

  Future<void> fetchAvailableServices() async {
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

  void toggleService(int id, double price, bool selected) {
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
    });
  }

  void togglePackageUsage(bool value) {
    setState(() {
      usePackage = value;
      if (usePackage) {
        totalPrice = 0; // Free when using package
      } else {
        // Recalculate total based on selected services
        totalPrice = 0;
        for (int serviceId in selectedServices) {
          final service = services.firstWhere((s) => s['id'] == serviceId);
          totalPrice += service['price'];
        }
      }
    });
  }

  Future<void> submitOrder() async {
    if (selectedCarId == null ||
        selectedServices.isEmpty ||
        selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select location, car, and at least one service'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // إنشاء بيانات الطلب
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

    // إنشاء معرف فريد للطلب
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    // الانتقال إلى شاشة الدفع
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          token: widget.token,
          amount: totalPrice,
          orderId: orderId,
          orderData: orderData,
        ),
      ),
    ).then((_) {
      // After payment screen is closed, navigate to orders
      _navigateToOrders();
    });
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
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                child: Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Packages Section - Professional Package Display
              if (packages.isNotEmpty) ...[
                sectionTitle('Available Packages'),
                const SizedBox(height: 16),
                Container(
                  height: 320,
                  child: PageView.builder(
                    controller: _packagePageController,
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final package = packages[index];
                      return OptimizedPackageCard(
                        package: package,
                        userPackage: userPackage,
                        onPurchase: () => _showPackagePurchaseDialog(package),
                        onViewDetails: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MyPackageScreen(
                                token: widget.token,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Page Indicators
                if (packages.length > 1) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      packages.length,
                      (index) {
                        final currentPage = _packagePageController.hasClients
                            ? _packagePageController.page?.round() ?? 0
                            : 0;
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == currentPage
                                ? Colors.black
                                : Colors.grey.shade300,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // View All Packages Button
                if (packages.length > 1) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllPackagesScreen(
                              token: widget.token,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.view_list, color: Colors.black),
                      label: Text(
                        'View All Packages',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],

              sectionTitle('Address'),
              if (isLoadingAddresses)
                const Center(child: CircularProgressIndicator()),
              if (!isLoadingAddresses && savedAddresses.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...savedAddresses.map((addr) => Card(
                          color: selectedSavedAddress != null &&
                                  selectedSavedAddress!['id'] == addr['id']
                              ? Colors.green[50]
                              : Colors.white,
                          child: ListTile(
                            title: Text(
                                addr['label'] ?? addr['address'] ?? 'Address',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${addr['street'] ?? ''} ${addr['building'] ?? ''} ${addr['floor'] ?? ''} ${addr['apartment'] ?? ''}\n${addr['address'] ?? ''}',
                                style: const TextStyle(fontSize: 13)),
                            trailing: selectedSavedAddress != null &&
                                    selectedSavedAddress!['id'] == addr['id']
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
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
                            },
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],
                ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add New Address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
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
                    await addNewAddressDialog(
                        picked['latlng'], picked['address']);
                  }
                },
              ),
              const SizedBox(height: 28),

              // Package Section
              if (userPackage != null) ...[
                Card(
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
                              onChanged: togglePackageUsage,
                              activeColor: Colors.black,
                            ),
                            Text('Use Package',
                                style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],

              sectionTitle('Services'),
              ...services.map((s) {
                final price = double.tryParse(s['price'].toString()) ?? 0.0;
                final isAvailableInPackage = usePackage &&
                    availableServices
                        .any((service) => service['id'] == s['id']);
                final pointsRequired = usePackage && isAvailableInPackage
                    ? PackageService.getPointsRequiredForService(
                        availableServices, s['id'])
                    : null;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selectedServices.contains(s['id'])
                          ? Colors.black
                          : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: selectedServices.contains(s['id']),
                      activeColor: Colors.black,
                      onChanged: (val) =>
                          toggleService(s['id'], price, val ?? false),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(s['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        if (usePackage && isAvailableInPackage)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${pointsRequired ?? 0} Points',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else
                          Text(
                            '${price.toStringAsFixed(2)} AED',
                            style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 16),
                          ),
                      ],
                    ),
                    subtitle: Text(s['description'] ?? '',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                );
              }).toList(),
              const SizedBox(height: 28),
              sectionTitle('Your Car'),
              TextButton.icon(
                onPressed: () async {
                  final added = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddCarScreen(token: widget.token),
                    ),
                  );
                  if (added == true) fetchUserCars();
                },
                icon: const Icon(Icons.add_circle_outline, color: Colors.black),
                label: const Text('Add a new car',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 16)),
              ),
              ...cars.map((c) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selectedCarId == c['id']
                          ? Colors.black
                          : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: RadioListTile<int>(
                    value: c['id'],
                    groupValue: selectedCarId,
                    title: Text('${c['brand']['name']} ${c['model']['name']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Year: ${c['year']['year']} • Color: ${c['color']}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14)),
                        if (c['license_plate'] != null &&
                            c['license_plate'].toString().isNotEmpty)
                          Text('License Plate: ${c['license_plate']}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    onChanged: (val) => setState(() => selectedCarId = val),
                    activeColor: Colors.black,
                  ),
                );
              }).toList(),
              const SizedBox(height: 28),
              sectionTitle('Schedule'),
              SwitchListTile(
                title: const Text('Request for now',
                    style: TextStyle(fontSize: 16)),
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
              const SizedBox(height: 24),

              // Order Summary Card
              OrderSummaryCard(
                totalPrice: totalPrice,
                usePackage: usePackage,
                selectedServicesCount: selectedServices.length,
                remainingPoints: userPackage?['remaining_points'],
                totalPointsUsed: _calculateTotalPointsUsed(),
              ),

              const SizedBox(height: 24),

              // Submit Button
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
                  onPressed: submitOrder,
                  icon: Icon(usePackage ? Icons.card_giftcard : Icons.payment),
                  label: Text(
                    usePackage ? 'Use Package Points' : 'Proceed to Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: usePackage ? Colors.green : Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // دالة عرض نافذة شراء الباقة
  void _showPackagePurchaseDialog(Map<String, dynamic> package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Purchase Package',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (package['image'] != null)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '${dotenv.env['BASE_URL'] ?? 'http://localhost:8000'}/storage/${package['image']}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade200,
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          size: 50,
                          color: Colors.black,
                        ),
                      );
                    },
                  ),
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
            ),
            const SizedBox(height: 8),
            if (package['description'] != null)
              Text(
                package['description'],
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      'Price',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${package['price']} AED',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Points',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '${package['points']} Points',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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

  // دالة شراء الباقة
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
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      // إنشاء payment intent أولاً
      final paymentResponse = await http.post(
        Uri.parse('$baseUrl/api/payments/create-intent'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (priceValue * 100).round(), // تحويل إلى سنتات
          'currency': 'aed',
          'order_id': orderId,
          'description': 'Package: ${package['name']}',
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
            token: widget.token,
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

  // Navigate to orders screen after successful order
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

  Widget sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
        ),
      );
}
