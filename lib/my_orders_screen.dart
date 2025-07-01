import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final baseUrl = dotenv.env['BASE_URL']!;
    final res = await http.get(
      Uri.parse('$baseUrl/api/orders/my'),
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

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blueGrey;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.black;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String formatDateTime(String? datetime) {
    if (datetime == null) return 'N/A';
    DateTime dt = (DateTime.tryParse(datetime) ?? DateTime.now()).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
          title: null,
          flexibleSpace: SafeArea(
            child: Center(
              child: Image.asset('assets/logo.png', height: 100),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF5F5F7)],
          ),
        ),
        child: orders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final car = order['car'];
                  final services = order['services'] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الحالة + السعر
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order['id']} - ${order['status']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '💰 ${order['total']} AED',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          // العنوان
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: Colors.black54),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order['address'] ?? 'N/A',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // السيارة
                          Row(
                            children: [
                              const Icon(Icons.directions_car_outlined,
                                  color: Colors.black54),
                              const SizedBox(width: 8),
                              Text(
                                'Car: ${car != null ? '${car['brand']['name']} ${car['model']['name']}' : 'Car: Not available'}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // الخدمات
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cleaning_services_outlined,
                                  color: Colors.black54),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Services: ${services.map((s) => s['name']).join(" • ")}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // التاريخ
                          Row(
                            children: [
                              const Icon(Icons.access_time_outlined,
                                  color: Colors.black54),
                              const SizedBox(width: 8),
                              Text(
                                formatDateTime(order['scheduled_at']) != 'N/A'
                                    ? formatDateTime(order['scheduled_at'])
                                    : formatDateTime(order['created_at']),
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
