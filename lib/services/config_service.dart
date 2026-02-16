import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نتيجة فحص التحديث الإجباري من الـ API
class ForceUpdateResult {
  const ForceUpdateResult({required this.required, this.storeUrl});
  final bool required;
  final String? storeUrl;
}

/// إعدادات بانر الصفحة الرئيسية من الـ API
class HomeBannerConfig {
  const HomeBannerConfig({
    this.imageUrl,
    this.linkType = 'none',
    this.externalUrl,
  });
  final String? imageUrl;
  final String linkType;
  final String? externalUrl;
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

  static const _keyBannerImageUrl = 'home_banner_cached_image_url';
  static const _keyBannerLinkType = 'home_banner_cached_link_type';
  static const _keyBannerExternalUrl = 'home_banner_cached_external_url';

  /// جلب إعدادات البانر من الذاكرة المحلية (للعرض الفوري دون انتظار الـ API)
  static Future<HomeBannerConfig?> getCachedHomeBannerConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imageUrl = prefs.getString(_keyBannerImageUrl)?.trim();
      final linkType = prefs.getString(_keyBannerLinkType)?.trim() ?? 'none';
      final externalUrl = prefs.getString(_keyBannerExternalUrl)?.trim();
      if (imageUrl == null && (externalUrl == null || externalUrl.isEmpty) && (linkType.isEmpty || linkType == 'none')) {
        return null;
      }
      return HomeBannerConfig(
        imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
        linkType: linkType.isEmpty ? 'none' : linkType,
        externalUrl: (externalUrl != null && externalUrl.isNotEmpty) ? externalUrl : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// جلب إعدادات بانر الصفحة الرئيسية من الـ API (مع حفظها في الذاكرة المحلية)
  static Future<HomeBannerConfig> fetchHomeBannerConfig() async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/config'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return const HomeBannerConfig();

      final data = jsonDecode(res.body);
      final d = data['data'];
      if (d == null) return const HomeBannerConfig();

      var imageUrl = (d['home_banner_image_url'] ?? '').toString().trim();
      final linkType = (d['home_banner_link_type'] ?? 'none').toString().trim();
      final externalUrl = (d['home_banner_link_external_url'] ?? '').toString().trim();

      // إذا الرابط من السيرفر يستخدم localhost/127.0.0.1، الجهاز لا يصل له — نستبدل بأساس الـ API (BASE_URL)
      if (imageUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(imageUrl);
          final host = uri.host.toLowerCase();
          if (host == 'localhost' || host == '127.0.0.1') {
            final base = baseUrl.replaceFirst(RegExp(r'/$'), '');
            final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
            imageUrl = base + path;
          }
        } catch (_) {}
      }

      final config = HomeBannerConfig(
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        linkType: linkType.isEmpty ? 'none' : linkType,
        externalUrl: externalUrl.isEmpty ? null : externalUrl,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyBannerImageUrl, imageUrl);
        await prefs.setString(_keyBannerLinkType, config.linkType);
        await prefs.setString(_keyBannerExternalUrl, config.externalUrl ?? '');
      } catch (_) {}
      return config;
    } catch (e) {
      print('⚠️ ConfigService fetchHomeBannerConfig error: $e');
      return const HomeBannerConfig();
    }
  }
}
