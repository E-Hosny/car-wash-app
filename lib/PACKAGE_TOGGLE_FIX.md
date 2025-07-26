# إصلاح مشكلة Package Toggle

## المشكلة
عند اختيار خدمة وتفعيل `use package` ثم إغلاقه مرة أخرى، كان النظام يتوقف بسبب خطأ في حساب السعر.

## السبب
في دالة `togglePackageUsage`، عندما يتم إغلاق `use package`، كان الكود يحاول إعادة حساب السعر باستخدام `service['price']` مباشرة، لكن `price` قد يكون `String` وليس `double`، مما يسبب خطأ في العمليات الحسابية.

## الحل

### 1. إصلاح `togglePackageUsage`
```dart
void togglePackageUsage(bool value) {
  setState(() {
    usePackage = value;
    if (usePackage) {
      totalPrice = 0; // Free when using package
    } else {
      // Recalculate total based on selected services
      totalPrice = 0;
      for (int serviceId in selectedServices) {
        try {
          final service = services.firstWhere((s) => s['id'] == serviceId);
          final price = double.tryParse(service['price'].toString()) ?? 0.0;
          totalPrice += price;
        } catch (e) {
          print('Error calculating price for service $serviceId: $e');
          // Continue with other services
        }
      }
    }
    // Ensure totalPrice doesn't go negative
    if (totalPrice < 0) {
      totalPrice = 0;
    }
  });
}
```

### 2. إصلاح `toggleService`
```dart
void toggleService(int id, double price, bool selected) {
  setState(() {
    if (selected) {
      selectedServices.add(id);
      if (!usePackage) {
        totalPrice += price;
      }
    } else {
      selectedServices.remove(id);
      if (!usePackage) {
        totalPrice -= price;
      }
    }
    // Ensure totalPrice doesn't go negative
    if (totalPrice < 0) {
      totalPrice = 0;
    }
  });
}
```

## التحسينات المضافة

### ✅ **معالجة الأخطاء:**
- استخدام `try-catch` لمعالجة الأخطاء المحتملة
- `double.tryParse()` بدلاً من التحويل المباشر
- القيمة الافتراضية `0.0` في حالة الفشل

### ✅ **حماية من القيم السالبة:**
- التأكد من أن `totalPrice` لا يصبح سالباً
- إعادة تعيينه إلى `0` إذا أصبح سالباً

### ✅ **استمرارية العمل:**
- في حالة حدوث خطأ مع خدمة واحدة، يستمر مع باقي الخدمات
- طباعة رسالة خطأ للمساعدة في التصحيح

## الاختبار

### للاختبار:
1. افتح التطبيق
2. اختر خدمة أو أكثر
3. فعّل `use package`
4. أغلقه مرة أخرى
5. تأكد من أن السعر يتم حسابه بشكل صحيح
6. تأكد من عدم توقف النظام

### النتيجة المتوقعة:
- ✅ لا يتوقف النظام
- ✅ يتم حساب السعر بشكل صحيح
- ✅ لا تظهر قيم سالبة
- ✅ تجربة مستخدم سلسة

## الملفات المعدلة
- `lib/order_request_screen.dart`
  - دالة `togglePackageUsage`
  - دالة `toggleService` 