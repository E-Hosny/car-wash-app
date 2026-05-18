import 'package:shared_preferences/shared_preferences.dart';

import '../translations.dart';
import 'cache_service.dart';

enum WashCategory { car, caravan, motorcycle }

enum CaravanSize { small, medium, large }

class WashContext {
  const WashContext({
    required this.category,
    this.caravanSize,
    this.carTypeKey,
    this.carId,
    this.carDisplayName,
  });

  final WashCategory category;
  final CaravanSize? caravanSize;
  final String? carTypeKey;
  final int? carId;
  final String? carDisplayName;

  String get categoryKey {
    switch (category) {
      case WashCategory.car:
        return 'car';
      case WashCategory.caravan:
        return 'caravan';
      case WashCategory.motorcycle:
        return 'motorcycle';
    }
  }

  String? get caravanSizeKey {
    if (caravanSize == null) return null;
    switch (caravanSize!) {
      case CaravanSize.small:
        return 'small';
      case CaravanSize.medium:
        return 'medium';
      case CaravanSize.large:
        return 'large';
    }
  }
}

class WashContextService {
  static const _keyCategory = 'wash_category';
  static const _keyCaravanSize = 'wash_caravan_size';
  static const _keyCarTypeKey = 'wash_car_type_key';

  static Future<void> save(WashContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCategory, context.categoryKey);
    if (context.caravanSizeKey != null) {
      await prefs.setString(_keyCaravanSize, context.caravanSizeKey!);
    } else {
      await prefs.remove(_keyCaravanSize);
    }
    if (context.carTypeKey != null && context.carTypeKey!.isNotEmpty) {
      await prefs.setString(_keyCarTypeKey, context.carTypeKey!);
    } else {
      await prefs.remove(_keyCarTypeKey);
    }
  }

  /// يزامن سياق الصفحة الرئيسية مع أحدث سيارة. يُرجع null إن لم توجد سيارات.
  static Future<WashContext?> syncDefaultCarContext(String token) async {
    final cars = await CacheService().getCars(token);
    if (cars.isEmpty) return null;

    final latest = cars.last;
    final carTypeKey = latest['car_type']?.toString();
    final ctx = WashContext(
      category: WashCategory.car,
      carTypeKey: carTypeKey?.isNotEmpty == true ? carTypeKey : null,
      carId: _parseCarId(latest['id']),
      carDisplayName: carDisplayName(latest),
    );
    await save(ctx);
    return ctx;
  }

  static int? _parseCarId(dynamic id) {
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  static String carDisplayName(Map car) {
    try {
      final brand = car['brand'] is Map
          ? car['brand']['name']?.toString()
          : car['brand']?.toString();
      final model = car['model'] is Map
          ? car['model']['name']?.toString()
          : car['model']?.toString();
      if (brand != null &&
          brand.isNotEmpty &&
          model != null &&
          model.isNotEmpty) {
        return '$brand $model';
      }
      if (brand != null && brand.isNotEmpty) return brand;
      if (model != null && model.isNotEmpty) return model;
    } catch (_) {}
    final type = car['car_type']?.toString();
    if (type != null && type.isNotEmpty) return type;
    return '';
  }

  static Future<WashContext> load() async {
    final prefs = await SharedPreferences.getInstance();
    final category = prefs.getString(_keyCategory) ?? 'car';
    final caravanSize = prefs.getString(_keyCaravanSize);
    final carTypeKey = prefs.getString(_keyCarTypeKey);

    return WashContext(
      category: _parseCategory(category),
      caravanSize: caravanSize != null ? _parseCaravanSize(caravanSize) : null,
      carTypeKey: carTypeKey,
    );
  }

  /// كرفان بحجم محدد أو دراجة: يمكن عرض الرئيسية دون سيارات مسجّلة في الحساب.
  static bool canEnterHomeWithoutRegisteredCars(WashContext ctx) {
    return ctx.category == WashCategory.motorcycle ||
        (ctx.category == WashCategory.caravan && ctx.caravanSize != null);
  }

  /// لا نستبدل السياق بأحدث سيارة عندما المستخدم في مسار كرفان (بعد اختيار الحجم) أو دراجة.
  static bool shouldKeepSavedContextInsteadOfSyncingCar(WashContext saved) {
    return saved.category == WashCategory.motorcycle ||
        (saved.category == WashCategory.caravan && saved.caravanSize != null);
  }

  /// عند فتح الرئيسية مع وجود سيارات: زامن أحدث سيارة إلا إن كان المستخدم في مسار كرفان/دراجة.
  static Future<WashContext?> syncHomeEntryContext(String token) async {
    final saved = await load();
    if (shouldKeepSavedContextInsteadOfSyncingCar(saved)) {
      return saved;
    }
    return syncDefaultCarContext(token);
  }

  static WashCategory _parseCategory(String value) {
    switch (value) {
      case 'caravan':
        return WashCategory.caravan;
      case 'motorcycle':
        return WashCategory.motorcycle;
      default:
        return WashCategory.car;
    }
  }

  static String displayLabel({
    required WashCategory category,
    CaravanSize? caravanSize,
    required String language,
  }) {
    switch (category) {
      case WashCategory.caravan:
        final base = _tr('wash_type_caravan', language);
        final sizeKey = switch (caravanSize) {
          CaravanSize.small => 'caravan_size_small',
          CaravanSize.medium => 'caravan_size_medium',
          CaravanSize.large => 'caravan_size_large',
          null => '',
        };
        if (sizeKey.isEmpty) return base;
        return '$base · ${_tr(sizeKey, language)}';
      case WashCategory.motorcycle:
        return _tr('wash_type_motorcycle', language);
      case WashCategory.car:
        return _tr('wash_type_car', language);
    }
  }

  static String displayLabelFromOrder(
    Map order,
    String language,
  ) {
    final category = _parseCategory(order['wash_category']?.toString() ?? 'car');
    final sizeStr = order['caravan_size']?.toString();
    final caravanSize =
        sizeStr != null && sizeStr.isNotEmpty ? _parseCaravanSize(sizeStr) : null;
    return displayLabel(
      category: category,
      caravanSize: caravanSize,
      language: language,
    );
  }

  static String _tr(String key, String language) {
    return AppTranslations.getTextWithFallback(key, language);
  }

  static CaravanSize _parseCaravanSize(String value) {
    switch (value) {
      case 'medium':
        return CaravanSize.medium;
      case 'large':
        return CaravanSize.large;
      default:
        return CaravanSize.small;
    }
  }
}
