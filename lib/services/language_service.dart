import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'app_language';
  static const String defaultLanguage = 'en';
  
  // Get current language
  static Future<String> getCurrentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? defaultLanguage;
    } catch (e) {
      return defaultLanguage;
    }
  }
  
  // Set current language
  static Future<bool> setCurrentLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_languageKey, language);
    } catch (e) {
      return false;
    }
  }
  
  // Check if current language is Arabic
  static Future<bool> isArabic() async {
    final lang = await getCurrentLanguage();
    return lang == 'ar';
  }
  
  // Check if current language is RTL
  static Future<bool> isRTL() async {
    return await isArabic();
  }
}
