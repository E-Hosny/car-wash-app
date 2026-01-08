import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripeService {
  // إنشاء Payment Intent مع دعم PaymentSheet
  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    required String currency,
    required String orderId,
    required String token,
    double? latitude,
    double? longitude,
    bool isPackagePurchase = false,
  }) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      
      // بناء body مع إضافة الموقع إذا كان متوفراً
      final bodyData = {
        'amount': amount,
        'currency': currency,
        'order_id': orderId,
      };
      
      // إضافة is_package_purchase إذا كان شراء باقة
      if (isPackagePurchase) {
        bodyData['is_package_purchase'] = true;
        print('📦 Package purchase detected - location not required');
      }
      
      // إضافة الموقع إذا كان متوفراً (للطلبات العادية)
      if (latitude != null && longitude != null) {
        bodyData['latitude'] = latitude;
        bodyData['longitude'] = longitude;
        print('📍 Sending location to API: latitude=$latitude, longitude=$longitude');
        print('📍 Location type: lat=${latitude.runtimeType}, lng=${longitude.runtimeType}');
      } else if (!isPackagePurchase) {
        print('⚠️ WARNING: Location not provided (latitude=$latitude, longitude=$longitude)');
        print('⚠️ This will cause API validation to fail for regular orders!');
      }
      
      print('📤 Payment Intent Request Body: ${jsonEncode(bodyData)}');
      print('📤 Request body keys: ${bodyData.keys.toList()}');
      print('📤 Has latitude in body: ${bodyData.containsKey('latitude')}');
      print('📤 Has longitude in body: ${bodyData.containsKey('longitude')}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // التأكد من وجود جميع البيانات المطلوبة لـ PaymentSheet
        if (data['client_secret'] != null &&
            data['ephemeral_key'] != null &&
            data['customer'] != null) {
          return data;
        } else {
          throw Exception('Missing required payment data');
        }
      } else {
        // محاولة استخراج رسالة الخطأ من الاستجابة
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? 
                              errorData['error'] ?? 
                              'Failed to create payment intent';
          throw Exception(errorMessage);
        } catch (parseError) {
          throw Exception('Failed to create payment intent: ${response.body}');
        }
      }
    } catch (e) {
      throw Exception('Error creating payment intent: $e');
    }
  }

  // الحصول على Publishable Key
  static String getPublishableKey() {
    return dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
  }
}
