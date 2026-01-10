import 'package:logrocket_flutter/logrocket_flutter.dart';
import 'dart:convert';

/// Helper class for LogRocket logging and privacy protection
class LogRocketHelper {
  /// Log informational message
  static void logInfo(String message) {
    try {
      LogRocket.info(message);
    } catch (e) {
      print("⚠️ Warning: LogRocket.info failed: $e");
    }
  }

  /// Log warning message
  static void logWarn(String message) {
    try {
      LogRocket.warn(message);
    } catch (e) {
      print("⚠️ Warning: LogRocket.warn failed: $e");
    }
  }

  /// Log error message
  static void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    try {
      if (error != null) {
        LogRocket.error('$message: $error');
      } else {
        LogRocket.error(message);
      }
    } catch (e) {
      print("⚠️ Warning: LogRocket.error failed: $e");
    }
  }

  /// Remove sensitive headers from a headers map
  static Map<String, String> sanitizeHeaders(Map<String, String> headers) {
    final sanitized = Map<String, String>.from(headers);
    
    // Remove Authorization header
    sanitized.remove('Authorization');
    sanitized.remove('authorization');
    
    // Remove other potentially sensitive headers
    sanitized.remove('X-Auth-Token');
    sanitized.remove('x-auth-token');
    sanitized.remove('Cookie');
    sanitized.remove('cookie');
    
    return sanitized;
  }

  /// Sanitize request body to mask sensitive data
  static String sanitizeRequestBody(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final sanitized = Map<String, dynamic>.from(decoded);
      
      // Mask passwords
      if (sanitized.containsKey('password')) {
        sanitized['password'] = '***MASKED***';
      }
      if (sanitized.containsKey('password_confirmation')) {
        sanitized['password_confirmation'] = '***MASKED***';
      }
      
      // Mask tokens
      if (sanitized.containsKey('token')) {
        sanitized['token'] = '***MASKED***';
      }
      if (sanitized.containsKey('auth_token')) {
        sanitized['auth_token'] = '***MASKED***';
      }
      if (sanitized.containsKey('access_token')) {
        sanitized['access_token'] = '***MASKED***';
      }
      if (sanitized.containsKey('refresh_token')) {
        sanitized['refresh_token'] = '***MASKED***';
      }
      
      // Mask API keys
      if (sanitized.containsKey('api_key')) {
        sanitized['api_key'] = '***MASKED***';
      }
      if (sanitized.containsKey('secret')) {
        sanitized['secret'] = '***MASKED***';
      }
      
      return jsonEncode(sanitized);
    } catch (e) {
      // If body is not JSON, return as is (or mask common patterns)
      return body.replaceAllMapped(
        RegExp(r'("(?:password|token|auth_token|access_token|refresh_token|api_key|secret)"\s*:\s*")[^"]*(")'),
        (match) => '${match.group(1)}***MASKED***${match.group(2)}',
      );
    }
  }

  /// Identify user in LogRocket
  static void identifyUser(String userId, {String? name, String? email}) {
    try {
      final traits = <String, String>{};
      if (name != null && name.isNotEmpty) {
        traits['name'] = name;
      }
      if (email != null && email.isNotEmpty) {
        traits['email'] = email;
      }
      
      LogRocket.identify(userId, traits);
      print("✅ LogRocket user identified: $userId");
    } catch (e) {
      print("⚠️ Warning: LogRocket.identify failed: $e");
    }
  }
}

