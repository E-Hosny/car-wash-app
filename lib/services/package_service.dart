import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PackageService {
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  // Get all available packages
  static Future<Map<String, dynamic>> getPackages(String token) async {
    try {
      if (_baseUrl == null || _baseUrl!.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/packages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load packages: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Get user's current package
  static Future<Map<String, dynamic>> getCurrentPackage(String token) async {
    try {
      if (_baseUrl == null || _baseUrl!.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/packages/my/current'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': true,
          'data': null, // No active package
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load current package: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Get available services for current package
  static Future<Map<String, dynamic>> getPackageServices(String token) async {
    try {
      if (_baseUrl == null || _baseUrl!.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/packages/my/services'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data']['available_services'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to load package services: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Purchase a package
  static Future<Map<String, dynamic>> purchasePackage(
    String token,
    Map<String, dynamic> package,
  ) async {
    try {
      if (_baseUrl == null || _baseUrl!.isEmpty) {
        throw Exception('BASE_URL not configured');
      }

      final price = package['price'];
      if (price == null) {
        throw Exception('Package price is missing');
      }

      final priceValue = double.tryParse(price.toString());
      if (priceValue == null) {
        throw Exception('Invalid package price: $price');
      }

      final orderId = DateTime.now().millisecondsSinceEpoch.toString();

      final response = await http.post(
        Uri.parse('$_baseUrl/api/payments/create-intent'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (priceValue * 100).round(),
          'currency': 'aed',
          'order_id': orderId,
          'description': 'Package: ${package['name']}',
        }),
      );

      if (response.statusCode == 200) {
        final paymentData = jsonDecode(response.body);
        return {
          'success': true,
          'data': {
            'payment_intent_id': paymentData['client_secret'],
            'order_id': orderId,
            'package_id': package['id'],
            'amount': priceValue,
          },
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to create payment intent: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error creating payment: ${e.toString()}',
      };
    }
  }

  // Validate package points
  static int validatePoints(dynamic points) {
    if (points == null) return 0;
    if (points is int) return points;
    if (points is String) {
      final parsed = int.tryParse(points);
      return parsed ?? 0;
    }
    if (points is double) return points.toInt();
    return 0;
  }

  // Format points display
  static String formatPoints(dynamic points) {
    final validatedPoints = validatePoints(points);
    return '$validatedPoints Points';
  }

  // Check if service is available in package
  static bool isServiceAvailableInPackage(
    List<dynamic> availableServices,
    int serviceId,
  ) {
    return availableServices.any((service) => service['id'] == serviceId);
  }

  // Get points required for service
  static int getPointsRequiredForService(
    List<dynamic> availableServices,
    int serviceId,
  ) {
    final service = availableServices.firstWhere(
      (service) => service['id'] == serviceId,
      orElse: () => {'points_required': 0},
    );
    return validatePoints(service['points_required']);
  }
}
