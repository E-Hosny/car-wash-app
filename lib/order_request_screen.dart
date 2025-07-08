import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_car_screen.dart';
import 'main_navigation_screen.dart';
import 'map_picker_screen.dart';
import 'payment_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class OrderRequestScreen extends StatefulWidget {
  final String token;

  const OrderRequestScreen({super.key, required this.token});

  @override
  State<OrderRequestScreen> createState() => _OrderRequestScreenState();
}

class _OrderRequestScreenState extends State<OrderRequestScreen> {
  double? latitude;
  double? longitude;
  GoogleMapController? _mapController;
  LatLng? selectedLocation;
  String? selectedAddress;

  List services = [];
  List cars = [];
  List selectedServices = [];
  int? selectedCarId;
  double totalPrice = 0;

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
    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.get(
      Uri.parse('$baseUrl/api/services'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) {
      setState(() {
        services = jsonDecode(res.body);
      });
    }
  }

  Future<void> fetchUserCars() async {
    final baseUrl = dotenv.env['BASE_URL']!;
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
  }

  Future<void> fetchSavedAddresses() async {
    setState(() => isLoadingAddresses = true);
    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.get(
      Uri.parse('$baseUrl/api/addresses'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );
    if (res.statusCode == 200) {
      setState(() {
        savedAddresses = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        isLoadingAddresses = false;
      });
    } else {
      setState(() => isLoadingAddresses = false);
    }
  }

  void toggleService(int id, double price, bool selected) {
    setState(() {
      if (selected) {
        selectedServices.add(id);
        totalPrice += price;
      } else {
        selectedServices.remove(id);
        totalPrice -= price;
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
                  decoration:
                      InputDecoration(labelText: 'Label (e.g. Home, Work)'),
                ),
                TextField(
                  controller: streetController,
                  decoration: InputDecoration(labelText: 'Street'),
                ),
                TextField(
                  controller: buildingController,
                  decoration: InputDecoration(labelText: 'Building'),
                ),
                TextField(
                  controller: floorController,
                  decoration: InputDecoration(labelText: 'Floor'),
                ),
                TextField(
                  controller: apartmentController,
                  decoration: InputDecoration(labelText: 'Apartment'),
                ),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: 'Notes'),
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
                      final baseUrl = dotenv.env['BASE_URL']!;
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
              sectionTitle('Services'),
              ...services.map((s) {
                final price = double.tryParse(s['price'].toString()) ?? 0.0;
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
                        Text(
                          '${price.toStringAsFixed(2)} AED',
                          style: const TextStyle(
                              color: Colors.green,
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
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${totalPrice.toStringAsFixed(2)} AED',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
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
                      icon: const Icon(Icons.payment),
                      label: const Text(
                        'Proceed to Payment',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
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
