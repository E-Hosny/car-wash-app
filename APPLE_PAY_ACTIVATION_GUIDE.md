# دليل تفعيل Apple Pay - خطوة بخطوة
# Apple Pay Activation Guide - Step by Step

## 🍎 متطلبات تفعيل Apple Pay

### 1. حساب Apple Developer
- ✅ حساب مدفوع ($99/سنة)
- ✅ صلاحيات Admin أو Account Holder

### 2. Merchant ID
- ✅ إنشاء Merchant ID في Apple Developer Console
- ✅ تفعيل Apple Pay Capability

### 3. Domain Verification
- ✅ Domain مسجل ويعمل
- ✅ ملف التحقق من Stripe

### 4. Xcode Configuration
- ✅ إضافة Merchant ID في Entitlements
- ✅ تحديث Info.plist

---

## 🚀 الخطوات التفصيلية

### الخطوة 1: Apple Developer Console

#### 1.1 إنشاء Merchant ID
1. افتح [developer.apple.com](https://developer.apple.com)
2. سجل دخول بحسابك المدفوع
3. اذهب إلى **Certificates, Identifiers & Profiles**
4. اختر **Identifiers** من القائمة الجانبية
5. اضغط **+** في الأعلى لإنشاء identifier جديد
6. اختر **Merchant IDs**
7. اضغط **Continue**
8. أدخل:
   - **Description:** `Luxuria Car Wash`
   - **Identifier:** `merchant.com.luxuria.carwash` (أو اسم فريد)
9. اضغط **Continue** ثم **Register**

#### 1.2 تفعيل Apple Pay في App ID
1. في **Identifiers**، اختر App ID الخاص بك (مثل `com.luxuria.carwash`)
2. اضغط **Edit**
3. في قسم **Capabilities**، فعّل **Apple Pay**
4. اضغط **Configure**
5. اختر Merchant ID الذي أنشأته (`merchant.com.luxuria.carwash`)
6. اضغط **Continue**
7. اضغط **Save**

---

### الخطوة 2: Stripe Dashboard

#### 2.1 إضافة Domain
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. تأكد من أنك في **Live mode** (ليس Test mode)
3. اذهب إلى **Settings** > **Payment methods**
4. اختر **Apple Pay**
5. اضغط **Add domain**
6. أدخل domain الخاص بك: `yourdomain.com`
7. اضغط **Add domain**

#### 2.2 تحميل ملف التحقق
1. بعد إضافة الـ domain، ستظهر رسالة:
   ```
   Please add this file to your domain:
   https://yourdomain.com/.well-known/apple-developer-merchantid-domain-association
   ```

2. حمّل الملف الذي يظهر
3. ارفعه على خادمك في المسار:
   ```
   https://yourdomain.com/.well-known/apple-developer-merchantid-domain-association
   ```

4. تأكد من أن الملف يمكن الوصول إليه:
   ```bash
   curl https://yourdomain.com/.well-known/apple-developer-merchantid-domain-association
   ```

#### 2.3 التحقق من Domain
1. في Stripe Dashboard، اضغط **Verify domain**
2. يجب أن ترى ✅ بجانب الـ domain
3. إذا فشل، تحقق من:
   - الملف موجود في المسار الصحيح
   - الملف يمكن الوصول إليه من الإنترنت
   - لا توجد مشاكل في SSL

---

### الخطوة 3: تحديث Xcode

#### 3.1 إضافة Entitlements

**ملف: `ios/Runner/Runner.entitlements`**

إذا لم يكن موجوداً، أنشئه:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.in-app-payments</key>
    <array>
        <string>merchant.com.luxuria.carwash</string>
    </array>
</dict>
</plist>
```

#### 3.2 تحديث Info.plist

**ملف: `ios/Runner/Info.plist`**

أضف قبل `</dict>`:

```xml
<key>PKPaymentNetworks</key>
<array>
    <string>visa</string>
    <string>mastercard</string>
    <string>amex</string>
</array>
```

#### 3.3 تحديث Xcode Project

1. افتح `ios/Runner.xcworkspace` في Xcode
2. اختر Target **Runner**
3. اذهب إلى **Signing & Capabilities**
4. اضغط **+ Capability**
5. اختر **Apple Pay**
6. في قسم **Merchant IDs**، أضف:
   - `merchant.com.luxuria.carwash`
7. احفظ التغييرات

---

### الخطوة 4: تحديث Flutter Code

**ملف: `lib/payment_screen.dart`**

استبدل:

```dart
// دعم Google Pay
// ملاحظة: Apple Pay معطّل مؤقتاً لأنه يحتاج merchantIdentifier
// لتفعيله، راجع APPLE_PAY_SETUP.md
googlePay: const PaymentSheetGooglePay(
  merchantCountryCode: 'AE',
  testEnv: true,
),
```

بـ:

```dart
// دعم Apple Pay و Google Pay
applePay: const PaymentSheetApplePay(
  merchantCountryCode: 'AE',
  merchantIdentifier: 'merchant.com.luxuria.carwash', // ✅ أضف هنا
),
googlePay: const PaymentSheetGooglePay(
  merchantCountryCode: 'AE',
  testEnv: true,
),
```

---

### الخطوة 5: الاختبار

#### 5.1 على جهاز حقيقي
- Apple Pay **لا يعمل على المحاكي**
- يجب استخدام iPhone حقيقي

#### 5.2 إضافة بطاقة اختبار
1. افتح **Wallet** على iPhone
2. اضغط **+** لإضافة بطاقة
3. في وضع Test، استخدم بطاقات Stripe الاختبارية:
   ```
   Card: 4242 4242 4242 4242
   Expiry: 12/34
   CVC: 123
   ```

#### 5.3 اختبار الدفع
1. شغّل التطبيق على iPhone
2. اذهب إلى شاشة الدفع
3. اضغط "Initialize Payment"
4. اضغط "Pay XX.XX AED"
5. يجب أن ترى خيار **Apple Pay** 🍎
6. اختره وأكمل الدفع بـ Face ID/Touch ID

---

## 🔧 استكشاف الأخطاء

### خطأ: "merchantIdentifier must be specified"
**الحل:** تأكد من إضافة `merchantIdentifier` في الكود

### خطأ: "Apple Pay not available"
**الحل:**
- تأكد من استخدام جهاز حقيقي (ليس محاكي)
- تأكد من إضافة بطاقة في Wallet
- تأكد من تفعيل Apple Pay في Xcode

### خطأ: "Domain verification failed"
**الحل:**
- تأكد من رفع ملف التحقق على الخادم
- تأكد من أن الملف يمكن الوصول إليه:
  ```
  https://yourdomain.com/.well-known/apple-developer-merchantid-domain-association
  ```

### Apple Pay لا يظهر في PaymentSheet
**الحل:**
- تأكد من أن `merchantIdentifier` صحيح
- تأكد من تفعيل Apple Pay في App ID
- تأكد من إضافة Merchant ID في Entitlements

---

## 💰 التكلفة

### Apple Developer Account
- **$99/سنة** - مطلوب لإنشاء Merchant ID

### Domain
- **مجاني** إذا كان لديك domain بالفعل
- **~$10-15/سنة** إذا كنت تحتاج domain جديد

### المجموع
- **~$109-114/سنة** للتكلفة الكاملة

---

## ⏱️ الوقت المطلوب

### إعداد Apple Developer
- **30 دقيقة** - إنشاء Merchant ID
- **15 دقيقة** - تفعيل Apple Pay في App ID

### إعداد Stripe
- **20 دقيقة** - إضافة Domain
- **10 دقيقة** - تحميل ملف التحقق

### إعداد Xcode
- **15 دقيقة** - تحديث Entitlements و Info.plist
- **10 دقيقة** - إضافة Apple Pay Capability

### إعداد Flutter
- **5 دقائق** - تحديث الكود

### المجموع
- **~1.5 ساعة** للإعداد الكامل

---

## ✅ قائمة التحقق النهائية

قبل الاختبار، تأكد من:

- [ ] حساب Apple Developer مدفوع ($99/سنة)
- [ ] Merchant ID منشأ ومفعل
- [ ] Apple Pay مفعل في App ID
- [ ] Domain مضاف في Stripe
- [ ] ملف التحقق مرفوع على الخادم
- [ ] Domain محقق في Stripe ✅
- [ ] Entitlements محدثة
- [ ] Info.plist محدث
- [ ] Apple Pay Capability مضاف في Xcode
- [ ] merchantIdentifier مضاف في الكود
- [ ] iPhone حقيقي للاختبار
- [ ] بطاقة مضافة في Wallet

---

## 🎯 النتيجة المتوقعة

بعد إكمال جميع الخطوات:

```
┌─────────────────────────────┐
│ Choose payment method:      │
│                             │
│ 💳 Card                    │
│ 🍎 Apple Pay               │ ← ✅ سيظهر الآن!
│ 📱 Google Pay               │
│ 🔗 Link                     │
└─────────────────────────────┘
```

---

## 📞 الدعم

إذا واجهت أي مشاكل:

### Apple Developer Support
- [developer.apple.com/support](https://developer.apple.com/support)

### Stripe Support
- [support.stripe.com](https://support.stripe.com)

### Flutter Stripe Issues
- [github.com/flutter-stripe/flutter_stripe/issues](https://github.com/flutter-stripe/flutter_stripe/issues)

---

## 🎉 الخلاصة

بعد إكمال هذا الدليل، ستحصل على:

- ✅ **4 طرق دفع** بدلاً من 3
- ✅ **Apple Pay** يعمل على iPhone
- ✅ **دفع بنقرة واحدة** مع Face ID/Touch ID
- ✅ **تجربة مستخدم ممتازة** للمستخدمين الإماراتيين

---

**آخر تحديث:** 19 أكتوبر 2024

🚀 **ابدأ الآن - Apple Pay يستحق الاستثمار!**

