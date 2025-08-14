import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'order_request_screen.dart';
import 'main_navigation_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final String token;

  const MyOrdersScreen({super.key, required this.token});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List orders = [];
  bool isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoading = true; // Start loading
    });

    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/my'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final ordersData = jsonDecode(res.body);

        if (ordersData != null && ordersData is List) {
          setState(() {
            orders = ordersData;
            isLoading = false; // Stop loading
          });
        } else {
          setState(() {
            orders = [];
            isLoading = false; // Stop loading
          });
        }
      } else {
        setState(() {
          orders = [];
          isLoading = false; // Stop loading
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          orders = [];
          isLoading = false; // Stop loading
        });
      }
    }
  }

  String _getCarDisplayName(dynamic carData) {
    try {
      if (carData == null) return 'Car data not available';

      // Handle both old format (object with name) and new format (direct string)
      String? brandName;
      String? modelName;

      if (carData['brand'] is Map) {
        brandName = carData['brand']?['name'];
      } else {
        brandName = carData['brand']?.toString();
      }

      if (carData['model'] is Map) {
        modelName = carData['model']?['name'];
      } else {
        modelName = carData['model']?.toString();
      }

      if (brandName != null && modelName != null) {
        return '$brandName $modelName';
      } else if (brandName != null) {
        return brandName;
      } else if (modelName != null) {
        return modelName;
      } else {
        return 'Car information unavailable';
      }
    } catch (e) {
      return 'Car data error';
    }
  }

  String _getServicesDisplayText(dynamic services) {
    try {
      if (services == null || services is! List) return 'No services';

      final servicesList = services;
      if (servicesList.isEmpty) return 'No services';

      final serviceNames = servicesList
          .map((s) {
            // Handle both old format (object with name) and new format (direct string)
            if (s is Map && s['name'] != null) {
              return s['name'].toString();
            } else if (s is String) {
              return s;
            } else {
              return 'Unknown Service';
            }
          })
          .where((name) => name.isNotEmpty)
          .toList();

      return serviceNames.isNotEmpty
          ? serviceNames.join(' • ')
          : 'No valid services';
    } catch (e) {
      return 'Services data error';
    }
  }

  String formatDateTime(String? datetime) {
    if (datetime == null) return 'N/A';
    DateTime dt = (DateTime.tryParse(datetime) ?? DateTime.now()).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildOrderCard(dynamic order, int index) {
    try {
      if (order == null) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('❌ Order data is null'),
            ),
          ),
        );
      }

      final bool isMultiCar = order['is_multi_car'] ?? false;
      final car = order['car'];
      final services = order['services'] ?? [];
      final allCars = order['all_cars'] ?? [];

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
                  Row(
                    children: [
                      Text(
                        'Order #${order['id']} - ${order['status']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      if (isMultiCar) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Multi',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                  const Icon(Icons.location_on_outlined, color: Colors.black54),
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

              // السيارة/السيارات
              if (isMultiCar && allCars.isNotEmpty) ...[
                // عرض السيارات المتعددة
                Row(
                  children: [
                    const Icon(Icons.directions_car_outlined,
                        color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(
                      'Cars: ${order['cars_count'] ?? allCars.length} vehicles',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // تفاصيل كل سيارة
                for (int i = 0; i < allCars.length; i++) ...[
                  _buildMultiCarDetail(allCars[i], i),
                ]
              ] else ...[
                // عرض السيارة الواحدة (النظام القديم)
                Row(
                  children: [
                    const Icon(Icons.directions_car_outlined,
                        color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Car: ${_getCarDisplayName(car)}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // الخدمات للسيارة الواحدة
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cleaning_services_outlined,
                        color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Services: ${_getServicesDisplayText(services)}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),

              // التاريخ
              Row(
                children: [
                  const Icon(Icons.access_time_outlined, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    formatDateTime(order['scheduled_at']) != 'N/A'
                        ? formatDateTime(order['scheduled_at'])
                        : formatDateTime(order['created_at']),
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '❌ Error displaying order #${index + 1}',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Error: ${e.toString()}',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMultiCarDetail(dynamic carDetail, int carIndex) {
    try {
      final carData = carDetail; // The car data is directly in carDetail
      final carServices =
          carDetail != null ? (carDetail['services'] ?? []) : [];

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🚗 Car ${carIndex + 1}: ${_getCarDisplayName(carData)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              '🔧 Services: ${_getServicesDisplayText(carServices)}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          '❌ Error displaying car ${carIndex + 1}',
          style: TextStyle(color: Colors.red, fontSize: 12),
        ),
      );
    }
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Orders Yet',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You haven\'t placed any orders yet.\nStart by creating your first order!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 30),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MainNavigationScreen(
                                  token: widget.token,
                                  initialIndex: 0, // New Order tab
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_shopping_cart,
                                  size: 20,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Create New Order',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
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
                      // Orders List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) =>
                              _buildOrderCard(orders[index], index),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
