# قائمة التحقق قبل النشر للإنتاج
# Production Deployment Checklist

## ⚠️ مهم جداً - اقرأ قبل النشر!

هذه القائمة تضمن أن نظام الدفع يعمل بشكل صحيح في الإنتاج.

---

## 📋 Backend (Laravel API)

### 1. تحديث Stripe Keys
```env
# في ملف .env
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxxxxxxxxxx  # ✅ غيّر من test إلى live
STRIPE_SECRET_KEY=sk_live_xxxxxxxxxxxxx       # ✅ غيّر من test إلى live
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx     # ✅ أضف webhook secret
```

**كيفية الحصول على المفاتيح:**
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. انقر على اسمك في الأعلى
3. اختر "View test data" وغيّرها إلى "View live data"
4. اذهب إلى **Developers** > **API keys**
5. انسخ المفاتيح

### 2. تفعيل طرق الدفع
- [ ] افتح Stripe Dashboard (Live Mode)
- [ ] اذهب إلى **Settings** > **Payment methods**
- [ ] فعّل:
  - [ ] Cards
  - [ ] Apple Pay
  - [ ] Google Pay
  - [ ] Link

### 3. إعداد Webhooks (اختياري لكن مهم)
- [ ] اذهب إلى **Developers** > **Webhooks**
- [ ] اضغط "Add endpoint"
- [ ] أضف URL: `https://yourdomain.com/api/webhooks/stripe`
- [ ] اختر الأحداث:
  - [ ] `payment_intent.succeeded`
  - [ ] `payment_intent.payment_failed`
- [ ] انسخ Webhook Secret وأضفه في `.env`

### 4. قاعدة البيانات
```bash
# تأكد من تشغيل Migration على الإنتاج
php artisan migrate --force
```

### 5. التحقق من الإعدادات
```bash
# اختبر الاتصال بـ Stripe
php artisan tinker
>>> \Stripe\Stripe::setApiKey(env('STRIPE_SECRET_KEY'));
>>> \Stripe\Customer::all(['limit' => 1]);
```

---

## 📱 Frontend (Flutter App)

### 1. تحديث Environment Variables

**ملف: `assets/.env` أو `test_local.env`**
```env
# تحديث للإنتاج
BASE_URL=https://api.yourdomain.com  # ✅ غيّر من localhost
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxxxxxxxxxx  # ✅ غيّر من test إلى live
```

### 2. تحديث Google Pay Settings

**ملف: `lib/payment_screen.dart`**
```dart
// ابحث عن هذا السطر:
testEnv: true,  // ❌ وضع الاختبار

// غيّره إلى:
testEnv: false,  // ✅ وضع الإنتاج
```

**الموقع الدقيق (حوالي السطر 182):**
```dart
googlePay: PaymentSheetGooglePay(
  merchantCountryCode: 'AE',
  testEnv: false,  // ✅ غيّر هنا
),
```

### 3. إعداد Apple Pay (مهم جداً!)

#### 3.1 Apple Developer Console
1. افتح [developer.apple.com](https://developer.apple.com)
2. اذهب إلى **Certificates, Identifiers & Profiles**
3. اختر **Identifiers**
4. اختر App ID الخاص بك
5. فعّل **Apple Pay**
6. أنشئ **Merchant ID** جديد (مثل: `merchant.com.yourcompany.carwash`)

#### 3.2 Stripe Dashboard
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. اذهب إلى **Settings** > **Payment methods**
3. اختر **Apple Pay**
4. اضغط "Add domain"
5. أضف domain الخاص بك
6. حمّل ملف التحقق

#### 3.3 تحديث Xcode
**ملف: `ios/Runner/Runner.entitlements`**
```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.com.yourcompany.carwash</string>
</array>
```

**ملف: `ios/Runner/Info.plist`**
```xml
<key>PKPaymentNetworks</key>
<array>
    <string>visa</string>
    <string>mastercard</string>
    <string>amex</string>
</array>
```

### 4. تحديث App Version
**ملف: `pubspec.yaml`**
```yaml
version: 1.1.7+27  # ✅ زد الرقم
```

### 5. Build للإنتاج

#### Android:
```bash
flutter build appbundle --release
```

#### iOS:
```bash
flutter build ipa --release
```

---

## 🧪 الاختبار النهائي

### قبل النشر، اختبر:

#### 1. البطاقات الحقيقية
- [ ] استخدم بطاقة حقيقية (بمبلغ صغير)
- [ ] تحقق من نجاح الدفع
- [ ] تحقق من Stripe Dashboard
- [ ] تحقق من قاعدة البيانات

#### 2. Apple Pay
- [ ] اختبر على iPhone حقيقي
- [ ] استخدم بطاقة حقيقية في Apple Wallet
- [ ] تحقق من نجاح الدفع

#### 3. Google Pay
- [ ] اختبر على Android حقيقي
- [ ] استخدم بطاقة حقيقية في Google Pay
- [ ] تحقق من نجاح الدفع

#### 4. سيناريوهات مختلفة
- [ ] دفع ناجح
- [ ] دفع مرفوض (بطاقة غير صالحة)
- [ ] إلغاء الدفع
- [ ] مستخدمين مختلفين
- [ ] مبالغ مختلفة

---

## 🔒 الأمان

### تأكد من:
- [ ] HTTPS مفعّل على الخادم
- [ ] SSL Certificate صالح
- [ ] API Keys آمنة (لا تشاركها)
- [ ] Webhook Secret محفوظ بأمان
- [ ] قاعدة البيانات محمية
- [ ] Firewall مفعّل

---

## 📊 المراقبة

### بعد النشر:

#### 1. Stripe Dashboard
- راقب الدفعات في الوقت الفعلي
- تحقق من معدل النجاح
- راقب الأخطاء

#### 2. Laravel Logs
```bash
tail -f storage/logs/laravel.log
```

#### 3. قاعدة البيانات
```sql
-- راقب الطلبات الجديدة
SELECT COUNT(*) FROM orders WHERE created_at > NOW() - INTERVAL 1 HOUR;

-- راقب حالة الدفع
SELECT payment_status, COUNT(*) 
FROM orders 
WHERE created_at > NOW() - INTERVAL 1 DAY
GROUP BY payment_status;
```

---

## 🚨 خطة الطوارئ

### إذا حدثت مشكلة:

#### 1. مشكلة في الدفع
- تحقق من Stripe Dashboard
- راجع Laravel logs
- تحقق من API Keys
- تحقق من اتصال الإنترنت

#### 2. Apple Pay لا يعمل
- تحقق من Merchant ID
- تحقق من Domain في Stripe
- تحقق من Entitlements

#### 3. Google Pay لا يعمل
- تحقق من `testEnv: false`
- تحقق من إعدادات Google Pay في Stripe

#### 4. الرجوع للنسخة السابقة
```bash
# إذا لزم الأمر، ارجع للنسخة السابقة
git revert HEAD
git push
```

---

## ✅ قائمة التحقق النهائية

قبل النشر، تأكد من:

### Backend:
- [ ] تحديث Stripe Keys (Live)
- [ ] تفعيل طرق الدفع في Stripe
- [ ] إعداد Webhooks
- [ ] تشغيل Migration
- [ ] اختبار API

### Frontend:
- [ ] تحديث BASE_URL
- [ ] تحديث STRIPE_PUBLISHABLE_KEY (Live)
- [ ] تغيير `testEnv: false`
- [ ] إعداد Apple Pay
- [ ] تحديث App Version
- [ ] Build للإنتاج

### الاختبار:
- [ ] اختبار بطاقات حقيقية
- [ ] اختبار Apple Pay
- [ ] اختبار Google Pay
- [ ] اختبار سيناريوهات مختلفة

### الأمان:
- [ ] HTTPS مفعّل
- [ ] API Keys آمنة
- [ ] قاعدة البيانات محمية

### المراقبة:
- [ ] Stripe Dashboard جاهز
- [ ] Logs جاهزة
- [ ] خطة الطوارئ جاهزة

---

## 📞 جهات الاتصال للدعم

- **Stripe Support:** [support.stripe.com](https://support.stripe.com)
- **Stripe Status:** [status.stripe.com](https://status.stripe.com)
- **Flutter Stripe Issues:** [github.com/flutter-stripe/flutter_stripe/issues](https://github.com/flutter-stripe/flutter_stripe/issues)

---

## 🎉 بعد النشر الناجح

1. راقب الدفعات لأول 24 ساعة
2. تحقق من معدل النجاح
3. اجمع ملاحظات المستخدمين
4. احتفل بالنجاح! 🎊

---

**آخر تحديث:** 19 أكتوبر 2024
**الحالة:** 📝 جاهز للمراجعة

⚠️ **تذكير:** لا تنشر للإنتاج قبل إكمال جميع النقاط في هذه القائمة!

