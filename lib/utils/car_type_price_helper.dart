/// تعديل سعر الخدمة حسب نسبة زيادة نوع السيارة القادمة من الـ API (`car_type_percentage`).
class CarTypePriceHelper {
  CarTypePriceHelper._();

  static double percentageFromCarMap(dynamic car) {
    if (car == null || car is! Map) return 0.0;
    return double.tryParse((car['car_type_percentage'] ?? 0).toString()) ?? 0.0;
  }

  /// نسبة الزيادة لسيارة مختارة من قائمة `cars` (حسب `id`).
  static double percentageFromCarId(List<dynamic> cars, int? carId) {
    if (carId == null) return 0.0;
    try {
      final car = cars.firstWhere((c) => c['id'] == carId);
      return percentageFromCarMap(car);
    } catch (_) {
      return 0.0;
    }
  }

  static double applyMarkup(double basePrice, double percentage) {
    return basePrice * (1 + (percentage / 100));
  }
}
