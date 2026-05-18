import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../main_navigation_screen.dart';
import '../screens/wash_type_selection_screen.dart';
import '../services/wash_context_service.dart';

class PostLoginNavigation {
  static Future<bool> userHasCars(String token) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/cars'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) return decoded.isNotEmpty;
        if (decoded is Map && decoded['data'] is List) {
          return (decoded['data'] as List).isNotEmpty;
        }
      }
    } catch (_) {}
    return false;
  }

  /// بعد تسجيل الدخول: بلا سيارات ولا سياق كرفان/دراجة → نوع الغسلة؛ وإلا الرئيسية (مع الحفاظ على مسار الكرفان/الدراجة عند الحاجة).
  static Future<void> navigateAuthenticated(
    BuildContext context,
    String token, {
    bool replace = true,
  }) async {
    final hasCars = await userHasCars(token);
    if (!context.mounted) return;

    if (!hasCars) {
      final saved = await WashContextService.load();
      if (!WashContextService.canEnterHomeWithoutRegisteredCars(saved)) {
        _go(
          context,
          WashTypeSelectionScreen(token: token, allowSkip: false),
          replace: replace,
        );
        return;
      }
    } else {
      await WashContextService.syncHomeEntryContext(token);
      if (!context.mounted) return;
    }

    _go(
      context,
      MainNavigationScreen(token: token),
      replace: replace,
    );
  }

  static Future<void> navigateAfterLogin(
    BuildContext context,
    String token, {
    bool replace = true,
  }) =>
      navigateAuthenticated(context, token, replace: replace);

  static void _go(
    BuildContext context,
    Widget page, {
    required bool replace,
  }) {
    final route = MaterialPageRoute(builder: (_) => page);
    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }
}
