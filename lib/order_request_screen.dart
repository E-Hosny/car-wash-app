import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'my_orders_screen.dart';

class OrderRequestScreen extends StatefulWidget {
  final String token;

  const OrderRequestScreen({super.key, required this.token});

  @override
  State<OrderRequestScreen> createState() => _OrderRequestScreenState();
}

class _OrderRequestScreenState extends State<OrderRequestScreen> {
  double latitude = 24.7136;
  double longitude = 46.6753;

  List services = [];
  List cars = [];
  List selectedServices = [];
  int? selectedCarId;
  double totalPrice = 0;

  bool useCurrentTime = true;
  DateTime? selectedDateTime;

  @override
  void initState() {
    super.initState();
    fetchServices();
    fetchUserCars();
  }

  Future<void> fetchServices() async {
    final res = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/services'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (res.statusCode == 200) {
      setState(() {
        services = jsonDecode(res.body);
      });
    }
  }

  Future<void> fetchUserCars() async {
    final res = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/cars'),
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
    if (selectedCarId == null || selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please choose a car and at least one service')),
      );
      return;
    }

    final res = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'address': 'Test Location - Riyadh',
        'car_id': selectedCarId,
        'services': selectedServices,
        'scheduled_at':
            useCurrentTime ? null : selectedDateTime?.toIso8601String(),
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Order placed successfully')),
      );

      await Future.delayed(const Duration(seconds: 2));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MyOrdersScreen(token: widget.token),
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
      appBar: AppBar(title: const Text('🚗 Car Wash Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📍 Location (Mock)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child:
                  const Text('Map Placeholder', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 25),
            const Text('🧼 Choose Services',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...services.map((s) {
              final price = double.tryParse(s['price'].toString()) ?? 0.0;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: CheckboxListTile(
                  value: selectedServices.contains(s['id']),
                  title: Text('${s['name']} - ${price.toStringAsFixed(2)} SAR'),
                  subtitle: Text(s['description']),
                  onChanged: (val) => toggleService(s['id'], price, val!),
                ),
              );
            }).toList(),
            const SizedBox(height: 25),
            const Text('🚘 Select Your Car',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...cars.map((c) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: RadioListTile<int>(
                  value: c['id'],
                  groupValue: selectedCarId,
                  title: Text('${c['brand']['name']} ${c['model']['name']}'),
                  subtitle:
                      Text('Year: ${c['year']['year']} • Color: ${c['color']}'),
                  onChanged: (val) => setState(() => selectedCarId = val),
                ),
              );
            }).toList(),
            const SizedBox(height: 25),
            const Text('🕒 Schedule Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Use current time'),
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
                      ? '📅 Selected: ${selectedDateTime.toString()}'
                      : 'Choose Date & Time',
                ),
              ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🧾 Total: ${totalPrice.toStringAsFixed(2)} SAR',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: submitOrder,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm Order'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
