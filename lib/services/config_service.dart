import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// نتيجة فحص التحديث الإجباري من الـ API
class ForceUpdateResult {
  const ForceUpdateResult({required this.required, this.storeUrl});
  final bool required;
  final String? storeUrl;
}

class ConfigService {
  static Future<bool> fetchPackagesEnabled() async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/config'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final enabled = data['data']?['packages_enabled'];
        if (enabled is bool) return enabled;
        if (enabled is String)
          return enabled == '1' || enabled.toLowerCase() == 'true';
        if (enabled is num) return enabled == 1;
      }
    } catch (e) {
      print('⚠️ ConfigService error: $e');
    }
    return true; // default enabled
  }

  /// جلب إعدادات التحديث من الـ API وفحص إن كان التحديث إجبارياً
  static Future<ForceUpdateResult> checkForceUpdate() async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/config'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const ForceUpdateResult(required: false);

      final data = jsonDecode(res.body);
      final d = data['data'];
      if (d == null) return const ForceUpdateResult(required: false);

      final minAndroid = (d['min_android_version'] ?? '').toString().trim();
      final minIos = (d['min_ios_version'] ?? '').toString().trim();
      final androidStoreUrl = (d['android_store_url'] ?? '').toString().trim();
      final iosStoreUrl = (d['ios_store_url'] ?? '').toString().trim();

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final bool isAndroid = Platform.isAndroid;
      final minVersion = isAndroid ? minAndroid : minIos;
      final storeUrl = isAndroid ? androidStoreUrl : iosStoreUrl;

      if (minVersion.isEmpty) return const ForceUpdateResult(required: false);
      if (storeUrl.isEmpty) return const ForceUpdateResult(required: false);

      final needUpdate = _compareVersions(currentVersion, minVersion) < 0;
      return ForceUpdateResult(
        required: needUpdate,
        storeUrl: needUpdate ? storeUrl : null,
      );
    } catch (e) {
      print('⚠️ ConfigService checkForceUpdate error: $e');
      return const ForceUpdateResult(required: false);
    }
  }

  /// مقارنة إصدارين (مثل 1.2.6 و 1.2.7). يعيد -1 إذا a < b، 0 إذا متساويان، 1 إذا a > b
  static int _compareVersions(String a, String b) {
    final partsA = _versionParts(a);
    final partsB = _versionParts(b);
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va < vb) return -1;
      if (va > vb) return 1;
    }
    return 0;
  }

  static List<int> _versionParts(String v) {
    return v
        .split(RegExp(r'[.\s]'))
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
  }
}
