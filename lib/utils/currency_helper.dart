import '../services/language_service.dart';
import '../translations.dart';

class CurrencyHelper {
  /// Get currency symbol based on current language
  static Future<String> getCurrency() async {
    final language = await LanguageService.getCurrentLanguage();
    return AppTranslations.getCurrency(language);
  }

  /// Format price with currency symbol
  static Future<String> formatPrice(double price, {int decimals = 2}) async {
    final currency = await getCurrency();
    return '${price.toStringAsFixed(decimals)} $currency';
  }

  /// Format price with currency symbol (synchronous version - requires language)
  static String formatPriceSync(double price, String language, {int decimals = 2}) {
    final currency = AppTranslations.getCurrency(language);
    return '${price.toStringAsFixed(decimals)} $currency';
  }
}
