import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static Future<bool> fetchPackagesEnabled() async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/config'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final enabled = data['data']?['packages_enabled'];
        if (enabled is bool) return enabled;
        if (enabled is String)
          return enabled == '1' || enabled.toLowerCase() == 'true';
        if (enabled is num) return enabled == 1;
      }
    } catch (_) {}
    return true; // default enabled
  }
}
