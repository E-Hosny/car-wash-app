# دليل حل المشاكل - طرق الدفع
# Troubleshooting Guide - Payment Methods

## 🐛 المشاكل الشائعة وحلولها

---

## 1️⃣ "Payment failed. Please try again"

### الأعراض:
- رسالة خطأ حمراء تظهر في شاشة الدفع
- الدفع لا يكتمل

### الأسباب المحتملة:

#### أ) لم يتم الضغط على "Initialize Payment"
**الحل:**
1. اضغط على زر "Initialize Payment" أولاً
2. انتظر حتى تظهر رسالة "Multiple Payment Methods Available"
3. ثم اضغط على "Pay XX.XX AED"

#### ب) مشكلة في الاتصال بالخادم
**الحل:**
```bash
# تأكد من تشغيل الخادم
cd c:/xampp/htdocs/car-wash-api
php artisan serve
```

#### ج) مشكلة في Stripe Keys
**الحل:**
```bash
# تحقق من ملف .env
cd c:/xampp/htdocs/car-wash-api
cat .env | grep STRIPE

# يجب أن ترى:
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
STRIPE_SECRET_KEY=sk_test_xxx
```

#### د) مشكلة في stripe_customer_id
**الحل:**
```sql
-- تحقق من وجود الحقل
SELECT stripe_customer_id FROM users LIMIT 1;

-- إذا كان NULL، تحقق من Migration
php artisan migrate:status
```

---

## 2️⃣ "Failed to create payment intent"

### الأعراض:
- الخطأ يظهر عند الضغط على "Initialize Payment"
- لا يتم إنشاء Payment Intent

### الأسباب والحلول:

#### أ) التوكن غير صالح
**الحل:**
```bash
# أنشئ توكن جديد
cd c:/xampp/htdocs/car-wash-api
php artisan tinker --execute="echo \App\Models\User::first()->createToken('test')->plainTextToken;"
```

#### ب) الخادم لا يعمل
**الحل:**
```bash
# شغّل الخادم
php artisan serve

# تحقق من أنه يعمل
curl http://127.0.0.1:8000/api/health
```

#### ج) مشكلة في Stripe API
**الحل:**
```bash
# اختبر الاتصال بـ Stripe
php test_payment_sheet.php

# يجب أن ترى:
✅ client_secret: موجود
✅ ephemeral_key: موجود
✅ customer: موجود
```

---

## 3️⃣ PaymentSheet لا يظهر

### الأعراض:
- عند الضغط على "Pay XX.XX AED" لا يحدث شيء
- أو يظهر خطأ فوراً

### الأسباب والحلول:

#### أ) البيانات المطلوبة غير موجودة
**افحص Console Logs:**
```
Flutter run output:
🔄 Creating payment intent...
✅ Payment Intent created successfully
Client Secret: pi_xxx...
Ephemeral Key: ek_xxx...
Customer ID: cus_xxx
```

**إذا لم تر هذه الرسائل:**
- تحقق من أن "Initialize Payment" تم الضغط عليه
- تحقق من أن API يعمل

#### ب) مشكلة في تهيئة Stripe
**الحل:**
```dart
// في payment_screen.dart، تحقق من:
Stripe.publishableKey = StripeService.getPublishableKey();

// وتحقق من test_local.env:
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
```

#### ج) مشكلة في Stripe Version
**الحل:**
```yaml
# في pubspec.yaml، تحقق من:
flutter_stripe: ^10.1.0

# إذا كان مختلف، حدّث:
flutter pub upgrade flutter_stripe
```

---

## 4️⃣ Apple Pay لا يظهر

### الأعراض:
- في PaymentSheet، لا يظهر خيار Apple Pay

### الأسباب والحلول:

#### أ) تستخدم محاكي
**الحل:**
- Apple Pay لا يعمل على المحاكي
- استخدم جهاز iPhone حقيقي

#### ب) لا توجد بطاقة في Apple Wallet
**الحل:**
1. افتح Wallet على iPhone
2. أضف بطاقة
3. أعد تشغيل التطبيق

#### ج) Apple Pay غير مفعّل في Stripe
**الحل:**
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. اذهب إلى Settings > Payment methods
3. فعّل Apple Pay

---

## 5️⃣ Google Pay لا يظهر

### الأعراض:
- في PaymentSheet، لا يظهر خيار Google Pay

### الأسباب والحلول:

#### أ) تستخدم محاكي
**الحل:**
- Google Pay قد لا يعمل على بعض المحاكيات
- استخدم جهاز Android حقيقي

#### ب) Google Pay غير مثبت
**الحل:**
1. ثبّت Google Pay من Play Store
2. أضف بطاقة
3. أعد تشغيل التطبيق

#### ج) testEnv خاطئ
**الحل:**
```dart
// في payment_screen.dart، تحقق من:
googlePay: PaymentSheetGooglePay(
  merchantCountryCode: 'AE',
  testEnv: true, // ✅ للاختبار
),
```

---

## 6️⃣ "Unauthenticated" Error

### الأعراض:
```json
{"message":"Unauthenticated."}
```

### الحل:
```bash
# أنشئ توكن جديد
cd c:/xampp/htdocs/car-wash-api
php artisan tinker --execute="echo \App\Models\User::first()->createToken('test')->plainTextToken;"

# انسخ التوكن واستخدمه في التطبيق
```

---

## 7️⃣ "Missing required payment data"

### الأعراض:
- خطأ عند محاولة الدفع
- رسالة تقول أن بعض البيانات مفقودة

### الحل:

#### تحقق من API Response:
```bash
cd c:/xampp/htdocs/car-wash-api
php test_payment_sheet.php
```

**يجب أن ترى:**
```
✅ client_secret: موجود
✅ ephemeral_key: موجود
✅ customer: موجود
✅ payment_intent_id: موجود
```

**إذا كان أي منها مفقود:**
1. تحقق من `PaymentController.php`
2. تحقق من أن `getOrCreateStripeCustomer()` تعمل
3. تحقق من Stripe API Keys

---

## 8️⃣ الدفع ينجح لكن الطلب لا يُنشأ

### الأعراض:
- رسالة "Payment was successful"
- لكن لا يظهر طلب في قاعدة البيانات

### الحل:

#### تحقق من Logs:
```bash
cd c:/xampp/htdocs/car-wash-api
tail -f storage/logs/laravel.log
```

#### تحقق من قاعدة البيانات:
```sql
SELECT * FROM orders ORDER BY created_at DESC LIMIT 5;
```

#### تحقق من API Endpoint:
```bash
# اختبر إنشاء طلب
curl -X POST http://127.0.0.1:8000/api/orders \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"service_id":1,"car_id":1,...}'
```

---

## 9️⃣ "Payment Intent already succeeded"

### الأعراض:
- محاولة الدفع مرة أخرى بنفس Payment Intent
- رسالة خطأ من Stripe

### الحل:
- هذا طبيعي - Payment Intent يُستخدم مرة واحدة فقط
- اضغط "Back" وأنشئ طلب جديد
- أو اضغط "Try Again" لإنشاء Payment Intent جديد

---

## 🔟 Console Logs مفيدة

### ما يجب أن تراه في Console:

#### عند Initialize Payment:
```
🔄 Creating payment intent...
Amount: 50.0 AED
Order ID: 12345
📦 Payment data received: [client_secret, ephemeral_key, customer, payment_intent_id]
✅ Payment Intent created successfully
Client Secret: pi_xxx...
Ephemeral Key: ek_xxx...
Customer ID: cus_xxx
Payment Intent ID: pi_xxx
```

#### عند الدفع:
```
Starting PaymentSheet presentation...
PaymentSheet initialized, presenting...
Payment confirmed successfully via PaymentSheet
Processing successful payment...
Order created successfully: 12345
Payment status updated for order: 12345
Showing thank you dialog
```

---

## 🛠️ أدوات التشخيص

### 1. اختبار API:
```bash
cd c:/xampp/htdocs/car-wash-api
php test_payment_sheet.php
```

### 2. فحص قاعدة البيانات:
```sql
-- فحص المستخدمين
SELECT id, name, stripe_customer_id FROM users;

-- فحص الطلبات
SELECT id, payment_status, payment_intent_id FROM orders ORDER BY created_at DESC LIMIT 10;
```

### 3. فحص Logs:
```bash
# Laravel logs
tail -f c:/xampp/htdocs/car-wash-api/storage/logs/laravel.log

# Flutter logs
flutter run --verbose
```

### 4. فحص Stripe Dashboard:
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. اذهب إلى Payments
3. ابحث عن آخر دفعة
4. تحقق من الحالة والتفاصيل

---

## 📞 إذا لم تحل المشكلة

### 1. اجمع المعلومات:
- رسالة الخطأ الكاملة
- Console logs
- Laravel logs
- Stripe Dashboard screenshots

### 2. راجع التوثيق:
- [PAYMENT_TESTING_GUIDE.md](./PAYMENT_TESTING_GUIDE.md)
- [MULTIPLE_PAYMENT_METHODS_IMPLEMENTATION.md](./MULTIPLE_PAYMENT_METHODS_IMPLEMENTATION.md)

### 3. تحقق من:
- [Stripe Status](https://status.stripe.com) - هل Stripe يعمل؟
- [Flutter Stripe Issues](https://github.com/flutter-stripe/flutter_stripe/issues)

---

## ✅ قائمة التحقق السريعة

قبل أن تسأل عن مساعدة، تحقق من:

- [ ] الخادم يعمل (`php artisan serve`)
- [ ] Stripe Keys صحيحة في `.env`
- [ ] Migration تم تشغيله (`php artisan migrate`)
- [ ] التوكن صالح
- [ ] `test_payment_sheet.php` ينجح
- [ ] Console logs لا تظهر أخطاء
- [ ] Stripe Dashboard يعمل
- [ ] اتصال الإنترنت يعمل

---

**آخر تحديث:** 19 أكتوبر 2024

💡 **نصيحة:** احتفظ بهذا الملف مفتوحاً أثناء التطوير!

