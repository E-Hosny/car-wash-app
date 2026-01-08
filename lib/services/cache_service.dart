import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache storage
  Map<String, _CachedData> _cache = {};

  // TTL durations (in milliseconds)
  static const int _servicesTTL = 15 * 60 * 1000; // 15 minutes (increased for better performance - services don't change frequently)
  static const int _carsTTL = 5 * 60 * 1000; // 5 minutes (increased for better performance)
  static const int _addressesTTL = 5 * 60 * 1000; // 5 minutes (increased for better performance)
  static const int _ordersTTL = 2 * 60 * 1000; // 2 minutes

  // Cache keys
  static const String _servicesKey = 'services';
  static const String _carsKey = 'cars';
  static const String _addressesKey = 'addresses';
  static const String _timeSlotsKey = 'time_slots';
  static const String _ordersKey = 'orders';
  
  // TTL for time slots (30 seconds - they change frequently)
  static const int _timeSlotsTTL = 30 * 1000; // 30 seconds

  /// Get services from cache only (no API call) - checks TTL
  List<dynamic>? getCachedServices(String token) {
    final cacheKey = '${_servicesKey}_$token';
    if (_isValid(cacheKey, _servicesTTL)) {
      final cachedData = _cache[cacheKey]!.data;
      if (cachedData is Map && cachedData.containsKey('services')) {
        return List<dynamic>.from(cachedData['services']);
      } else if (cachedData is List) {
        // Old format - direct list
        return cachedData;
      }
    }
    return null;
  }

  /// Get services from cache even if expired (for instant display)
  List<dynamic>? getCachedServicesEvenExpired(String token) {
    final cacheKey = '${_servicesKey}_$token';
    if (_cache.containsKey(cacheKey)) {
      final cachedData = _cache[cacheKey]!.data;
      if (cachedData is Map && cachedData.containsKey('services')) {
        return List<dynamic>.from(cachedData['services']);
      } else if (cachedData is List) {
        // Old format - direct list
        return cachedData;
      }
    }
    return null;
  }

  /// Get user cars from cache only (no API call) - checks TTL
  List<dynamic>? getCachedCars(String token) {
    final cacheKey = '${_carsKey}_$token';
    if (_isValid(cacheKey, _carsTTL)) {
      return _cache[cacheKey]!.data as List<dynamic>;
    }
    return null;
  }

  /// Get user cars from cache even if expired (for instant display)
  List<dynamic>? getCachedCarsEvenExpired(String token) {
    final cacheKey = '${_carsKey}_$token';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.data as List<dynamic>;
    }
    return null;
  }

  /// Get saved addresses from cache only (no API call) - checks TTL
  List<Map<String, dynamic>>? getCachedAddresses(String token) {
    final cacheKey = '${_addressesKey}_$token';
    if (_isValid(cacheKey, _addressesTTL)) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
    }
    return null;
  }

  /// Get saved addresses from cache even if expired (for instant display)
  List<Map<String, dynamic>>? getCachedAddressesEvenExpired(String token) {
    final cacheKey = '${_addressesKey}_$token';
    if (_cache.containsKey(cacheKey)) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
    }
    return null;
  }

  /// Get orders from cache only (no API call) - checks TTL
  List<dynamic>? getCachedOrders(String token) {
    final cacheKey = '${_ordersKey}_$token';
    if (_isValid(cacheKey, _ordersTTL)) {
      return List<dynamic>.from(_cache[cacheKey]!.data);
    }
    return null;
  }

  /// Get services from cache or API
  Future<List<dynamic>> getServices(String token) async {
    final cacheKey = '${_servicesKey}_$token';
    
    // Check cache first
    if (_isValid(cacheKey, _servicesTTL)) {
      print('📦 Using cached services');
      final cachedData = _cache[cacheKey]!.data;
      if (cachedData is Map && cachedData.containsKey('services')) {
        return List<dynamic>.from(cachedData['services']);
      } else if (cachedData is List) {
        // Old format - direct list
        return cachedData;
      }
      return [];
    }

    // Fetch from API
    print('🌐 Fetching services from API');
    try {
      final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
      if (baseUrl.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/services'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout while fetching services');
        },
      );

      if (res.statusCode == 200) {
        final responseData = jsonDecode(res.body);
        print('📥 API Response type: ${responseData.runtimeType}');
        
        // Handle both old format (List) and new format (Object with services and cache_version)
        List<dynamic> services;
        int? cacheVersion;
        
        if (responseData is List) {
          // Old format - direct list
          print('📋 Using old format (List)');
          services = responseData;
        } else if (responseData is Map && responseData.containsKey('services')) {
          // New format - object with services and cache_version
          print('📋 Using new format (Object with services)');
          services = List<dynamic>.from(responseData['services'] ?? []);
          cacheVersion = responseData['cache_version'];
          print('📋 Services count: ${services.length}, Cache version: $cacheVersion');
        } else {
          print('⚠️ Unknown response format');
          services = [];
        }
        
        if (services.isEmpty) {
          print('⚠️ No services found in response');
        }
        
        // Store cache version with services data
        final cacheData = {
          'services': services,
          'cache_version': cacheVersion,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Update cache
        _cache[cacheKey] = _CachedData(cacheData, DateTime.now().millisecondsSinceEpoch);
        print('✅ Cached ${services.length} services');
        
        return services;
      } else {
        throw Exception('Failed to fetch services: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching services: $e');
      // Return cached data even if expired, if available
      if (_cache.containsKey(cacheKey)) {
        print('⚠️ Using expired cache as fallback');
        final cachedData = _cache[cacheKey]!.data;
        if (cachedData is Map && cachedData.containsKey('services')) {
          return List<dynamic>.from(cachedData['services']);
        } else if (cachedData is List) {
          return cachedData;
        }
        return [];
      }
      rethrow;
    }
  }

  /// Get user cars from cache or API
  Future<List<dynamic>> getCars(String token) async {
    final cacheKey = '${_carsKey}_$token';
    
    // Check cache first
    if (_isValid(cacheKey, _carsTTL)) {
      print('📦 Using cached cars');
      return _cache[cacheKey]!.data as List<dynamic>;
    }

    // Fetch from API
    print('🌐 Fetching cars from API');
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/cars'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final carsData = jsonDecode(res.body);
        final cars = carsData is List ? carsData : [];
        
        // Update cache
        _cache[cacheKey] = _CachedData(cars, DateTime.now().millisecondsSinceEpoch);
        
        return cars;
      } else {
        throw Exception('Failed to fetch cars: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching cars: $e');
      // Return cached data even if expired, if available
      if (_cache.containsKey(cacheKey)) {
        print('⚠️ Using expired cache as fallback');
        return _cache[cacheKey]!.data as List<dynamic>;
      }
      rethrow;
    }
  }

  /// Get booked time slots from cache or API
  Future<Map<String, dynamic>> getBookedTimeSlots(String token, DateTime date) async {
    final dateString = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    final cacheKey = '${_timeSlotsKey}_${dateString}_$token';
    
    // Check cache first
    if (_isValid(cacheKey, _timeSlotsTTL)) {
      print('📦 Using cached time slots for date: $dateString');
      return _cache[cacheKey]!.data as Map<String, dynamic>;
    }

    // Fetch from API
    print('🌐 Fetching time slots from API for date: $dateString');
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/booked-time-slots?date=$dateString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final timeSlotsData = {
          'booked_hours': List<int>.from(data['booked_hours'] ?? []),
          'unavailable_hours': List<int>.from(data['unavailable_hours'] ?? []),
        };
        
        // Update cache
        _cache[cacheKey] = _CachedData(timeSlotsData, DateTime.now().millisecondsSinceEpoch);
        
        return timeSlotsData;
      } else {
        throw Exception('Failed to fetch time slots: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching time slots: $e');
      // Return cached data even if expired, if available
      if (_cache.containsKey(cacheKey)) {
        print('⚠️ Using expired cache as fallback');
        return _cache[cacheKey]!.data as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  /// Get booked time slots directly from API without checking cache
  /// This is used in order_confirmation_screen to always get fresh data
  Future<Map<String, dynamic>> getBookedTimeSlotsFromAPI(String token, DateTime date) async {
    final dateString = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    final cacheKey = '${_timeSlotsKey}_${dateString}_$token';
    
    // Fetch from API directly (no cache check)
    print('🌐 Fetching time slots from API (no cache) for date: $dateString');
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/booked-time-slots?date=$dateString'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final timeSlotsData = {
          'booked_hours': List<int>.from(data['booked_hours'] ?? []),
          'unavailable_hours': List<int>.from(data['unavailable_hours'] ?? []),
        };
        
        // Update cache (for use in other screens)
        _cache[cacheKey] = _CachedData(timeSlotsData, DateTime.now().millisecondsSinceEpoch);
        
        return timeSlotsData;
      } else {
        throw Exception('Failed to fetch time slots: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching time slots from API: $e');
      rethrow;
    }
  }

  /// Get booked time slots from cache only (no API call) - checks TTL
  Map<String, dynamic>? getCachedTimeSlots(String token, DateTime date) {
    final dateString = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    final cacheKey = '${_timeSlotsKey}_${dateString}_$token';
    if (_isValid(cacheKey, _timeSlotsTTL)) {
      return Map<String, dynamic>.from(_cache[cacheKey]!.data);
    }
    return null;
  }

  /// Get booked time slots from cache even if expired (for instant display)
  Map<String, dynamic>? getCachedTimeSlotsEvenExpired(String token, DateTime date) {
    final dateString = date.toIso8601String().split('T')[0]; // YYYY-MM-DD format
    final cacheKey = '${_timeSlotsKey}_${dateString}_$token';
    if (_cache.containsKey(cacheKey)) {
      return Map<String, dynamic>.from(_cache[cacheKey]!.data);
    }
    return null;
  }

  /// Invalidate time slots cache for a specific date
  void invalidateTimeSlots(String token, DateTime date) {
    final dateString = date.toIso8601String().split('T')[0];
    final cacheKey = '${_timeSlotsKey}_${dateString}_$token';
    _cache.remove(cacheKey);
    print('🗑️ Time slots cache invalidated for date: $dateString');
  }

  /// Get saved addresses from cache or API
  Future<List<Map<String, dynamic>>> getAddresses(String token) async {
    final cacheKey = '${_addressesKey}_$token';
    
    // Check cache first
    if (_isValid(cacheKey, _addressesTTL)) {
      print('📦 Using cached addresses');
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
    }

    // Fetch from API
    print('🌐 Fetching addresses from API');
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/addresses'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final addressesData = jsonDecode(res.body);
        final addresses = List<Map<String, dynamic>>.from(addressesData);
        
        // Update cache
        _cache[cacheKey] = _CachedData(addresses, DateTime.now().millisecondsSinceEpoch);
        
        return addresses;
      } else {
        throw Exception('Failed to fetch addresses: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching addresses: $e');
      // Return cached data even if expired, if available
      if (_cache.containsKey(cacheKey)) {
        print('⚠️ Using expired cache as fallback');
        return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
      }
      rethrow;
    }
  }

  /// Invalidate cars cache (call after adding/editing/deleting a car)
  void invalidateCars(String token) {
    final cacheKey = '${_carsKey}_$token';
    _cache.remove(cacheKey);
    print('🗑️ Cars cache invalidated');
  }

  /// Invalidate addresses cache (call after adding/editing/deleting an address)
  void invalidateAddresses(String token) {
    final cacheKey = '${_addressesKey}_$token';
    _cache.remove(cacheKey);
    print('🗑️ Addresses cache invalidated');
  }

  /// Invalidate services cache (rarely needed)
  void invalidateServices(String token) {
    final cacheKey = '${_servicesKey}_$token';
    _cache.remove(cacheKey);
    print('🗑️ Services cache invalidated');
  }

  /// Get orders from cache or API
  Future<List<dynamic>> getOrders(String token) async {
    final cacheKey = '${_ordersKey}_$token';
    
    // Check cache first
    if (_isValid(cacheKey, _ordersTTL)) {
      print('📦 Using cached orders');
      return List<dynamic>.from(_cache[cacheKey]!.data);
    }

    // Fetch from API
    print('🌐 Fetching orders from API');
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/my'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (res.statusCode == 200) {
        final ordersData = jsonDecode(res.body);
        final orders = ordersData != null && ordersData is List ? ordersData : [];
        
        // Update cache
        _cache[cacheKey] = _CachedData(orders, DateTime.now().millisecondsSinceEpoch);
        print('✅ Cached ${orders.length} orders');
        
        return orders;
      } else {
        throw Exception('Failed to fetch orders: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching orders: $e');
      // Return cached data even if expired, if available
      if (_cache.containsKey(cacheKey)) {
        print('⚠️ Using expired cache as fallback');
        return List<dynamic>.from(_cache[cacheKey]!.data);
      }
      rethrow;
    }
  }

  /// Invalidate orders cache (call after creating/updating an order)
  void invalidateOrders(String token) {
    final cacheKey = '${_ordersKey}_$token';
    _cache.remove(cacheKey);
    print('🗑️ Orders cache invalidated');
  }

  /// Clear all cache for a token
  void clearCache(String token) {
    _cache.remove('${_servicesKey}_$token');
    _cache.remove('${_carsKey}_$token');
    _cache.remove('${_addressesKey}_$token');
    _cache.remove('${_ordersKey}_$token');
    print('🗑️ All cache cleared for token');
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    print('🗑️ All cache cleared');
  }

  /// Check if cache is valid
  bool _isValid(String key, int ttl) {
    if (!_cache.containsKey(key)) {
      return false;
    }

    final cachedData = _cache[key]!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final age = now - cachedData.timestamp;

    return age < ttl;
  }
}

/// Internal class to store cached data with timestamp
class _CachedData {
  final dynamic data;
  final int timestamp;

  _CachedData(this.data, this.timestamp);
}

