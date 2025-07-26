# إصلاح مشكلة Splash Screen

## المشكلة
التطبيق يقف عند شاشة Splash Screen (LUXURIA CAR WASH) ولا ينتقل إلى الشاشة التالية.

## الأسباب المحتملة

### 1. **ملف .env مفقود**
- ملف `assets/.env` غير موجود
- التطبيق لا يستطيع العثور على `BASE_URL`

### 2. **مشكلة في Token**
- لا يوجد token محفوظ
- Token غير صالح

### 3. **مشكلة في OrderRequestScreen**
- خطأ في `initState`
- مشكلة في API calls

## الحلول المطبقة

### 1. **إضافة Debugging**
```dart
// في splash_screen.dart
print('🔍 Checking login status...');
print('Token exists: ${token != null}');
print('Token length: ${token?.length ?? 0}');
```

### 2. **Fallback للـ BASE_URL**
```dart
// في order_request_screen.dart
final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
```

### 3. **Error Handling محسن**
```dart
try {
  // الكود
} catch (e) {
  print('❌ Error: $e');
  // Fallback navigation
}
```

### 4. **إضافة banner.png إلى pubspec.yaml**
```yaml
assets:
  - assets/logo.png
  - assets/banner.png
  - assets/.env
```

## خطوات الاختبار

### 1. **تحقق من Console**
- افتح Flutter console
- ابحث عن رسائل Debug
- تحقق من وجود أخطاء

### 2. **تحقق من Token**
- إذا كان هناك token، سيظهر:
  ```
  ✅ User is logged in, navigating to MainNavigationScreen
  ```
- إذا لم يكن هناك token، سيظهر:
  ```
  ❌ No token found, navigating to LoginScreen
  ```

### 3. **إنشاء ملف .env**
```bash
# في مجلد assets
echo "BASE_URL=http://localhost:8000" > .env
```

### 4. **إعادة تشغيل التطبيق**
```bash
flutter clean
flutter pub get
flutter run
```

## النتيجة المتوقعة

بعد تطبيق الإصلاحات:
- ✅ Splash Screen يعمل لمدة 2 ثانية
- ✅ ينتقل إلى LoginScreen إذا لم يكن هناك token
- ✅ ينتقل إلى MainNavigationScreen إذا كان هناك token
- ✅ OrderRequestScreen يعمل بدون أخطاء

## ملاحظات إضافية

- تأكد من أن API server يعمل على `http://localhost:8000`
- إذا كان API على عنوان مختلف، عدل `BASE_URL` في ملف `.env`
- يمكن إضافة المزيد من Debugging حسب الحاجة 