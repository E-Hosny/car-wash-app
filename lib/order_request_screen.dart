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

  @override
  void initState() {
    super.initState();
    fetchServices();
    fetchUserCars();
    determineCurrentPosition();
  }

  Future<void> determineCurrentPosition() async {
    await Permission.location.request();
    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
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
      setState(() {
        cars = jsonDecode(res.body);
      });
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

    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.post(
      Uri.parse('$baseUrl/api/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode({
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'address': selectedAddress ?? 'Selected from map',
        'car_id': selectedCarId,
        'services': selectedServices,
        'scheduled_at':
            useCurrentTime ? null : selectedDateTime?.toIso8601String(),
      }),
    );

    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Order placed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MainNavigationScreen(token: widget.token, initialIndex: 1),
        ),
      );
    } else {
      print(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to place order')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Order',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            )),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: isMapInteracting ? const NeverScrollableScrollPhysics() : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Location'),
            ElevatedButton.icon(
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
                  setState(() {
                    selectedLocation = picked['latlng'];
                    selectedAddress = picked['address'];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location selected!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.location_on),
              label: Text(selectedLocation == null
                  ? 'Pick location on map'
                  : 'Change location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (selectedLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedAddress != null)
                      Text(
                        selectedAddress!,
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                      ),
                    Text(
                      '(${selectedLocation!.latitude.toStringAsFixed(6)}, ${selectedLocation!.longitude.toStringAsFixed(6)})',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selectedServices.contains(s['id'])
                        ? Colors.black
                        : Colors.grey.shade300,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
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
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selectedCarId == c['id']
                        ? Colors.black
                        : Colors.grey.shade300,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
                      Text('Year: ${c['year']['year']} • Color: ${c['color']}',
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
              title:
                  const Text('Request for now', style: TextStyle(fontSize: 16)),
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
                      : 'Schedule for later',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
                ElevatedButton.icon(
                  onPressed: submitOrder,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Place Order',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      );
}
