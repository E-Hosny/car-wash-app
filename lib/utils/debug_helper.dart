import 'dart:convert';
import 'package:flutter/foundation.dart';

class DebugHelper {
  static void logApiResponse(String endpoint, dynamic response) {
    if (kDebugMode) {
      print('=== API Response: $endpoint ===');
      print('Response: ${jsonEncode(response)}');
      print('================================');
    }
  }

  static void logError(String context, dynamic error) {
    if (kDebugMode) {
      print('=== Error in $context ===');
      print('Error: $error');
      print('========================');
    }
  }

  static void logPackageData(Map<String, dynamic>? userPackage) {
    if (kDebugMode) {
      print('=== Package Data ===');
      print('User Package: ${jsonEncode(userPackage)}');
      print('===================');
    }
  }

  static void logAvailableServices(List<dynamic> availableServices) {
    if (kDebugMode) {
      print('=== Available Services ===');
      for (var service in availableServices) {
        print('Service ID: ${service['id']}');
        print('Service Name: ${service['name']}');
        print('Points Required: ${service['points_required']}');
        print('---');
      }
      print('==========================');
    }
  }

  static void logServiceData(List<dynamic> services) {
    if (kDebugMode) {
      print('=== All Services ===');
      for (var service in services) {
        print('Service ID: ${service['id']}');
        print('Service Name: ${service['name']}');
        print('Service Price: ${service['price']}');
        print('---');
      }
      print('===================');
    }
  }
}
