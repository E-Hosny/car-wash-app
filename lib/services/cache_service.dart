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
  static const int _servicesTTL = 5 * 60 * 1000; // 5 minutes
  static const int _carsTTL = 1 * 60 * 1000; // 1 minute
  static const int _addressesTTL = 1 * 60 * 1000; // 1 minute

  // Cache keys
  static const String _servicesKey = 'services';
  static const String _carsKey = 'cars';
  static const String _addressesKey = 'addresses';
  static const String _timeSlotsKey = 'time_slots';
  
  // TTL for time slots (30 seconds - they change frequently)
  static const int _timeSlotsTTL = 30 * 1000; // 30 seconds

  /// Get services from cache only (no API call)
  List<dynamic>? getCachedServices(String token) {
    final cacheKey = '${_servicesKey}_$token';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.data as List<dynamic>;
    }
    return null;
  }

  /// Get user cars from cache only (no API call)
  List<dynamic>? getCachedCars(String token) {
    final cacheKey = '${_carsKey}_$token';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.data as List<dynamic>;
    }
    return null;
  }

  /// Get saved addresses from cache only (no API call)
  List<Map<String, dynamic>>? getCachedAddresses(String token) {
    final cacheKey = '${_addressesKey}_$token';
    if (_cache.containsKey(cacheKey)) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
    }
    return null;
  }

  /// Get services from cache or API
  Future<List<dynamic>> getServices(String token) async {
    final cacheKey = '${_servicesKey}_$token';
    
    // Check cache first
    if (_isValid(cacheKey, _servicesTTL)) {
      print('📦 Using cached services');
      return _cache[cacheKey]!.data as List<dynamic>;
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
      );

      if (res.statusCode == 200) {
        final servicesData = jsonDecode(res.body);
        final services = servicesData is List ? servicesData : [];
        
        // Update cache
        _cache[cacheKey] = _CachedData(services, DateTime.now().millisecondsSinceEpoch);
        
        return services;
      } else {
        throw Exception('Failed to fetch services: ${res.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching services: $e');
      // Return cached data even if expired, if available
      if (_cache.containsKey(cacheKey)) {
        print('⚠️ Using expired cache as fallback');
        return _cache[cacheKey]!.data as List<dynamic>;
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

  /// Get booked time slots from cache only (no API call)
  Map<String, dynamic>? getCachedTimeSlots(String token, DateTime date) {
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

  /// Clear all cache for a token
  void clearCache(String token) {
    _cache.remove('${_servicesKey}_$token');
    _cache.remove('${_carsKey}_$token');
    _cache.remove('${_addressesKey}_$token');
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

