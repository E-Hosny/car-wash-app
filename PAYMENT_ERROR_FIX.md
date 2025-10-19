# إصلاح خطأ "Payment failed" 🔧
# Fix "Payment failed" Error

## 🎯 المشكلة

عند محاولة الدفع، تظهر رسالة:
```
❌ Payment failed. Please try again.
```

---

## ✅ الحل السريع

### الخطوة 1: تأكد من تشغيل الخادم
```bash
cd c:/xampp/htdocs/car-wash-api
php artisan serve
```

### الخطوة 2: أعد تشغيل التطبيق
```bash
cd c:/car_wash_app
flutter run
```

### الخطوة 3: اتبع الترتيب الصحيح
1. ✅ اضغط "Initialize Payment" **أولاً**
2. ✅ انتظر حتى تظهر رسالة "Multiple Payment Methods Available"
3. ✅ **ثم** اضغط "Pay XX.XX AED"

---

## 🔍 التشخيص التفصيلي

### افحص Console Logs

عند تشغيل التطبيق، يجب أن ترى:

#### ✅ Logs صحيحة:
```
🔄 Creating payment intent...
Amount: 30.0 AED
Order ID: 1760864528204
📦 Payment data received: [client_secret, ephemeral_key, customer, payment_intent_id]
✅ Payment Intent created successfully
Client Secret: pi_xxx...
Ephemeral Key: ek_xxx...
Customer ID: cus_xxx
Payment Intent ID: pi_xxx
Starting PaymentSheet presentation...
PaymentSheet initialized, presenting...
```

#### ❌ إذا رأيت:
```
❌ Failed to create payment intent: ...
```

**الحل:**
1. تحقق من اتصال الإنترنت
2. تحقق من أن الخادم يعمل
3. تحقق من التوكن

---

## 🧪 اختبار API

### اختبر أن API يعمل:
```bash
cd c:/xampp/htdocs/car-wash-api
php test_payment_sheet.php
```

### النتيجة المتوقعة:
```
✅ SUCCESS! Payment Intent created

✅ client_secret: pi_xxx...
✅ ephemeral_key: ek_xxx...
✅ customer: cus_xxx
✅ payment_intent_id: pi_xxx

🎉 All required fields are present!
```

### إذا فشل الاختبار:
```bash
# أنشئ توكن جديد
php artisan tinker --execute="echo \App\Models\User::first()->createToken('test')->plainTextToken;"

# احفظه في test_token.txt
echo "NEW_TOKEN_HERE" > test_token.txt

# أعد الاختبار
php test_payment_sheet.php
```

---

## 🔑 تحقق من Stripe Keys

### في Backend (.env):
```bash
cd c:/xampp/htdocs/car-wash-api
cat .env | grep STRIPE
```

**يجب أن ترى:**
```
STRIPE_PUBLISHABLE_KEY=pk_test_51QBy7wCMJLG6tciZ...
STRIPE_SECRET_KEY=sk_test_xxx...
```

### في Frontend (test_local.env):
```bash
cd c:/car_wash_app
cat test_local.env | grep STRIPE
```

**يجب أن ترى:**
```
STRIPE_PUBLISHABLE_KEY=pk_test_51QBy7wCMJLG6tciZ...
```

---

## 📊 تحقق من قاعدة البيانات

### تحقق من stripe_customer_id:
```sql
SELECT id, name, stripe_customer_id FROM users LIMIT 5;
```

**إذا كان NULL للجميع:**
```bash
# تحقق من Migration
cd c:/xampp/htdocs/car-wash-api
php artisan migrate:status

# إذا لم يتم تشغيله، شغّله:
php artisan migrate
```

---

## 🎯 الخطوات الصحيحة للدفع

### 1. في شاشة الدفع:
```
┌─────────────────────────────┐
│  Order Summary              │
│  Order ID: 1760864528204    │
│  Amount: 30.00 AED          │
│                             │
│  ┌───────────────────────┐  │
│  │ Initialize Payment    │  │ ← اضغط هنا أولاً
│  └───────────────────────┘  │
└─────────────────────────────┘
```

### 2. انتظر التحميل:
```
🔄 Loading...
```

### 3. بعد النجاح:
```
┌─────────────────────────────┐
│  💡 Multiple Payment Methods│
│     Available               │
│  Cards, Apple Pay, Google   │
│  Pay & more                 │
│                             │
│  ┌───────────────────────┐  │
│  │ Pay 30.00 AED         │  │ ← اضغط هنا ثانياً
│  └───────────────────────┘  │
└─────────────────────────────┘
```

### 4. اختر طريقة الدفع:
```
┌─────────────────────────────┐
│  Choose payment method:     │
│                             │
│  💳 Card                    │
│  🍎 Apple Pay               │
│  📱 Google Pay              │
│  🔗 Link                    │
└─────────────────────────────┘
```

---

## 🐛 الأخطاء الشائعة

### ❌ خطأ 1: الضغط على "Pay" مباشرة
**المشكلة:** لم يتم الضغط على "Initialize Payment" أولاً

**الحل:** اضغط "Initialize Payment" أولاً

### ❌ خطأ 2: الخادم لا يعمل
**المشكلة:** `php artisan serve` غير مشغّل

**الحل:**
```bash
cd c:/xampp/htdocs/car-wash-api
php artisan serve
```

### ❌ خطأ 3: التوكن منتهي
**المشكلة:** التوكن غير صالح

**الحل:**
```bash
# أنشئ توكن جديد
php artisan tinker --execute="echo \App\Models\User::first()->createToken('test')->plainTextToken;"
```

### ❌ خطأ 4: Stripe Keys خاطئة
**المشكلة:** المفاتيح غير صحيحة أو مفقودة

**الحل:** راجع ملف `.env` وتأكد من وجود المفاتيح

---

## 🔧 إصلاح متقدم

### إذا استمرت المشكلة:

#### 1. امسح Cache:
```bash
cd c:/xampp/htdocs/car-wash-api
php artisan cache:clear
php artisan config:clear
```

#### 2. أعد بناء التطبيق:
```bash
cd c:/car_wash_app
flutter clean
flutter pub get
flutter run
```

#### 3. تحقق من Stripe Dashboard:
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. اذهب إلى Developers > Logs
3. ابحث عن آخر طلب
4. تحقق من الأخطاء

---

## 📱 اختبار كامل

### اختبار شامل للنظام:

```bash
# 1. تشغيل الخادم
cd c:/xampp/htdocs/car-wash-api
php artisan serve

# 2. اختبار API (في نافذة جديدة)
php test_payment_sheet.php

# 3. تشغيل التطبيق (في نافذة جديدة)
cd c:/car_wash_app
flutter run

# 4. في التطبيق:
# - اختر خدمة
# - اختر سيارة
# - اضغط "Initialize Payment"
# - انتظر
# - اضغط "Pay XX.XX AED"
# - أدخل بطاقة: 4242 4242 4242 4242
# - أكمل الدفع
```

---

## ✅ التحديثات الأخيرة

تم إضافة logging محسّن في الكود:

### في `_createPaymentIntent()`:
```dart
print('🔄 Creating payment intent...');
print('Amount: ${widget.amount} AED');
print('Order ID: ${widget.orderId}');
// ... المزيد من logs
```

### في `_processPayment()`:
```dart
print('❌ Payment error: $e');
print('Error type: ${e.runtimeType}');
print('Error details: ${e.toString()}');
```

**الآن يمكنك رؤية تفاصيل الخطأ في Console!**

---

## 📞 إذا احتجت مساعدة

### راجع:
1. **[TROUBLESHOOTING_AR.md](./TROUBLESHOOTING_AR.md)** - دليل حل المشاكل الشامل
2. **[PAYMENT_TESTING_GUIDE.md](./PAYMENT_TESTING_GUIDE.md)** - دليل الاختبار
3. **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** - مرجع سريع

### افحص:
- Console logs في Flutter
- Laravel logs: `storage/logs/laravel.log`
- Stripe Dashboard: [dashboard.stripe.com](https://dashboard.stripe.com)

---

**آخر تحديث:** 19 أكتوبر 2024

🎉 **الآن جرّب مرة أخرى!**

