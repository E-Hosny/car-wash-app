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
  }) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final response = await http.post(
        Uri.parse('$baseUrl/api/payments/create-intent'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'order_id': orderId,
        }),
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
        throw Exception('Failed to create payment intent: ${response.body}');
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
