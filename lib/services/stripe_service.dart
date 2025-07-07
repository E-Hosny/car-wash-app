import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripeService {
  static const String _publishableKey =
      'pk_test_51QBy7wCMJLG6tciZfKvsEogik3Rhk1pSfEyaaiPldKGGkUNroUugRQCJdYMY10BfoE8zx8SabsZDIYkjVJR4Q5HF00EBYyFSn5';

  // إنشاء Payment Intent
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
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create payment intent: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating payment intent: $e');
    }
  }

  // الحصول على Publishable Key
  static String getPublishableKey() {
    return _publishableKey;
  }
}
