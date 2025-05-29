import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyOrdersScreen extends StatefulWidget {
  final String token;

  const MyOrdersScreen({super.key, required this.token});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List orders = [];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final res = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/orders/my'),
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (res.statusCode == 200) {
      setState(() {
        orders = jsonDecode(res.body);
      });
    } else {
      print('❌ Failed to fetch orders: ${res.body}');
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '🚧 Pending';
      case 'in_progress':
        return '🧼 In Progress';
      case 'completed':
        return '✅ Completed';
      case 'cancelled':
        return '❌ Cancelled';
      default:
        return status;
    }
  }

  String formatDateTime(String? datetime) {
    if (datetime == null) return 'N/A';
    DateTime dt = (DateTime.tryParse(datetime) ?? DateTime.now()).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final car = order['car'];
                final services = order['services'] ?? [];

                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getStatusText(order['status']),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('📍 Address: ${order['address'] ?? 'N/A'}'),
                        (car != null &&
                                car['brand'] != null &&
                                car['model'] != null)
                            ? Text(
                                '🚗 Car: ${car['brand']['name']} ${car['model']['name']}')
                            : const Text('🚗 Car: Not available'),
                        Text(
                          '🧼 Services: ${services.map((s) => s['name']).join(', ')}',
                        ),
                        Text(
                          '💰 Total: ${order['total'] ?? 0} SAR',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order['scheduled_at'] != null
                              ? '🕒 Scheduled at: ${formatDateTime(order['scheduled_at'])}'
                              : '🕒 Ordered at: ${formatDateTime(order['created_at'])}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
