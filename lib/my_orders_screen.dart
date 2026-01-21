import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';
import 'services/cache_service.dart';
import 'widgets/animated_loading_indicator.dart';
import 'screens/rate_app_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  final String token;
  final bool showSuccessMessage;
  final bool forceRefresh; // Force refresh orders when navigating from payment

  const MyOrdersScreen({
    super.key, 
    required this.token,
    this.showSuccessMessage = false,
    this.forceRefresh = false,
  });

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List orders = [];
  bool isLoading = true; // Add loading state
  String? errorMessage;
  int retryCount = 0;
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // Clear any existing snackbars when entering orders screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Show success message only if explicitly requested
        if (widget.showSuccessMessage) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Payment successful! Your order is being processed.'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        }
      }
    });
    
    // If forceRefresh is true, fetch orders directly with forceRefresh flag
    if (widget.forceRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          fetchOrders(forceRefresh: true);
        }
      });
    } else {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    // Try to load from cache first for instant display
    final cacheService = CacheService();
    final cachedOrders = cacheService.getCachedOrders(widget.token);
    
    if (cachedOrders != null && cachedOrders.isNotEmpty) {
      setState(() {
        orders = cachedOrders;
        isLoading = false;
        errorMessage = null;
      });
      print('📦 Loaded ${orders.length} orders from cache, refreshing in background...');
      
      // Refresh in background
      fetchOrders(showLoading: false);
    } else {
      // No cache, fetch from API
      await fetchOrders();
    }
  }

  Future<void> fetchOrders({bool showLoading = true, bool forceRefresh = false}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final cacheService = CacheService();
      
      // If force refresh, invalidate cache first
      if (forceRefresh) {
        cacheService.invalidateOrders(widget.token);
      }
      
      // Use cache service which handles caching automatically
      final ordersData = await cacheService.getOrders(widget.token);

      if (!mounted) return;

      setState(() {
        orders = ordersData;
        isLoading = false;
        errorMessage = null;
        retryCount = 0; // Reset retry count on success
      });
    } catch (e) {
      print('Error fetching orders: $e');
      if (!mounted) return;

      // Retry logic with exponential backoff
      if (retryCount < maxRetries) {
        retryCount++;
        final delay = Duration(seconds: retryCount * 2); // 2s, 4s, 6s
        print('🔄 Retrying order fetch (attempt $retryCount/$maxRetries) after ${delay.inSeconds}s...');
        
        await Future.delayed(delay);
        return fetchOrders(showLoading: showLoading, forceRefresh: forceRefresh);
      }

      // All retries failed, show error
      setState(() {
        isLoading = false;
        errorMessage = _getErrorMessage(e);
      });

      // Show error message to user
      if (mounted && showLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage ?? 'Failed to load orders. Please try again.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                retryCount = 0;
                fetchOrders();
              },
            ),
          ),
        );
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('timeout') || error.toString().contains('Connection timeout')) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (error.toString().contains('Failed host lookup') || error.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network settings.';
    } else if (error.toString().contains('401') || error.toString().contains('Unauthorized')) {
      return 'Session expired. Please login again.';
    } else if (error.toString().contains('500') || error.toString().contains('Internal Server Error')) {
      return 'Server error. Please try again later.';
    } else {
      return 'Failed to load orders. Please try again.';
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
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Order #${order['id']} - ${order['status']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '💰 ${order['total']} AED',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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
              
              // رسالة توضيحية للطلبات المعلقة
              if (order['status']?.toString().toLowerCase() == 'pending') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Our service team will arrive at the scheduled time',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to Load Orders',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'An error occurred while loading your orders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                retryCount = 0;
                fetchOrders();
              },
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
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
            ? const AnimatedLoadingIndicator(message: 'Loading your orders...')
            : errorMessage != null && orders.isEmpty
                ? _buildErrorWidget()
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
                      // Rate the app button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RateAppScreen(
                                    token: widget.token,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.star_rate),
                            label: const Text('Rate the service'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Orders List with Pull-to-Refresh
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            retryCount = 0; // Reset retry count on manual refresh
                            await fetchOrders(forceRefresh: true);
                          },
                          child: errorMessage != null && orders.isEmpty
                              ? _buildErrorWidget()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: orders.length,
                                  itemBuilder: (context, index) =>
                                      _buildOrderCard(orders[index], index),
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
