import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  Future<void> submitOrder() async {
    if (selectedCarId == null || selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please choose car and at least one service')),
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
        'scheduled_at': null,
      }),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Order placed successfully')),
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
      appBar: AppBar(title: const Text('Request Car Wash')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📍 Select Location (mock)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              height: 200,
              color: Colors.grey[300],
              alignment: Alignment.center,
              child: const Text('Map Placeholder'),
            ),
            const SizedBox(height: 20),
            const Text('🧼 Select Services',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...services.map((s) {
              return CheckboxListTile(
                value: selectedServices.contains(s['id']),
                title: Text(s['name']),
                subtitle: Text(s['description']),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selectedServices.add(s['id']);
                    } else {
                      selectedServices.remove(s['id']);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 20),
            const Text('🚗 Choose Car',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...cars.map((c) {
              return RadioListTile<int>(
                value: c['id'],
                groupValue: selectedCarId,
                title: Text(
                    '${c['brand']['name']} ${c['model']['name']} (${c['year']['year']})'),
                subtitle: Text('Color: ${c['color']}'),
                onChanged: (val) => setState(() => selectedCarId = val),
              );
            }),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: submitOrder,
                child: const Text('✅ Confirm Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
