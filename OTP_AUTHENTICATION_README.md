# نظام تسجيل الدخول باستخدام OTP عبر WhatsApp

## نظرة عامة
تم تعديل نظام تسجيل الدخول في تطبيق غسيل السيارات ليستخدم رمز التحقق (OTP) المرسل عبر WhatsApp بدلاً من كلمة المرور التقليدية.

## الميزات الجديدة

### 1. شاشة تسجيل الدخول المحدثة (`login_screen.dart`)
- إدخال رقم الهاتف فقط (بدون كلمة مرور)
- إرسال OTP عبر WhatsApp webhook
- التحقق من وجود المستخدم في النظام
- التوجيه إلى شاشة إدخال OTP

### 2. شاشة إدخال OTP الجديدة (`otp_screen.dart`)
- 4 حقول لإدخال رمز التحقق
- التحقق التلقائي عند إدخال جميع الأرقام
- إمكانية إعادة إرسال الرمز
- معالجة الأخطاء وعرض رسائل مناسبة

### 3. API Endpoints الجديدة
- `POST /api/check-phone` - التحقق من وجود رقم الهاتف
- `POST /api/login-with-otp` - تسجيل الدخول باستخدام OTP

### 4. زر تسجيل الخروج
- تم إضافة زر تسجيل الخروج في أعلى يمين الصفحة الرئيسية
- حذف التوكن وإعادة التوجيه إلى شاشة تسجيل الدخول

## كيفية العمل

### 1. إرسال OTP
```dart
// إنشاء رمز OTP
final String otpCode = phoneNumber == '971508949923'
    ? '0000'  // رمز ثابت للاختبار
    : (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

// إرسال عبر WhatsApp webhook
final webhookUrl = Uri.parse('https://www.uchat.com.au/api/iwh/7c12fdd537dcf07c2df40f2e230ed94b');
await http.post(
  webhookUrl,
  headers: {"Content-Type": "application/json"},
  body: jsonEncode({
    "phone_number": phoneNumber,
    "code": otpCode,
  }),
);
```

### 2. التحقق من OTP
```dart
// التحقق من الرمز المدخل
if (enteredOtp == storedOtp) {
  // نجح التحقق، إكمال تسجيل الدخول
  await _completeLogin();
}
```

### 3. إكمال تسجيل الدخول
```dart
// استدعاء API للحصول على التوكن
final response = await http.post(
  Uri.parse('$baseUrl/api/login-with-otp'),
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
  body: jsonEncode({
    'phone': phoneNumber,
  }),
);
```

## التعديلات في الخادم

### 1. إضافة Routes جديدة
```php
// ✅ OTP Authentication
Route::post('/check-phone', [AuthController::class, 'checkPhone']);
Route::post('/login-with-otp', [AuthController::class, 'loginWithOtp']);
```

### 2. إضافة Methods في AuthController
- `checkPhone()` - التحقق من وجود رقم الهاتف
- `loginWithOtp()` - تسجيل الدخول باستخدام OTP

## الأمان
- يتم حفظ OTP مؤقتاً في SharedPreferences
- يتم حذف OTP بعد نجاح تسجيل الدخول
- التحقق من صحة الرمز قبل إكمال العملية

## الاختبار
- الرقم `971508949923` يستخدم رمز `0000` للاختبار
- باقي الأرقام تستخدم رمز عشوائي من 4 أرقام

## ملاحظات مهمة
1. تأكد من أن WhatsApp webhook يعمل بشكل صحيح
2. تأكد من إضافة المستخدمين في قاعدة البيانات
3. يمكن تخصيص رسائل الخطأ حسب الحاجة
4. يمكن إضافة ميزات إضافية مثل حظر إعادة الإرسال لفترة محددة 