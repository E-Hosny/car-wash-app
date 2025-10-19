# إعداد Apple Pay - دليل كامل
# Apple Pay Setup Guide

## ⚠️ ملاحظة مهمة

Apple Pay **معطّل حالياً** في التطبيق لأنه يحتاج إلى `merchantIdentifier`.

**الطرق المتاحة حالياً:**
- ✅ البطاقات (Cards)
- ✅ Google Pay
- ✅ Link
- ❌ Apple Pay (يحتاج إعداد)

---

## 🍎 لماذا Apple Pay معطّل؟

عند محاولة تفعيل Apple Pay بدون `merchantIdentifier`، يظهر الخطأ:

```
Failed assertion: line 454 pos 9: 
'(paymentSheetParameters.applePay?.merchantIdentifier == null): 
merchantIdentifier must be specified if you are using Apple Pay.'
```

**الحل:** إما إعداد Apple Pay بشكل كامل، أو تركه معطّلاً.

---

## 📋 متطلبات تفعيل Apple Pay

### 1. حساب Apple Developer
- ✅ حساب مدفوع ($99/سنة)
- ✅ صلاحيات Admin

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

## 🚀 خطوات التفعيل الكاملة

### الخطوة 1: Apple Developer Console

#### 1.1 إنشاء Merchant ID
1. افتح [developer.apple.com](https://developer.apple.com)
2. اذهب إلى **Certificates, Identifiers & Profiles**
3. اختر **Identifiers**
4. اضغط **+** لإنشاء identifier جديد
5. اختر **Merchant IDs**
6. أدخل:
   - **Description:** Luxuria Car Wash
   - **Identifier:** `merchant.com.luxuria.carwash` (أو اسم فريد)
7. اضغط **Continue** ثم **Register**

#### 1.2 تفعيل Apple Pay في App ID
1. في **Identifiers**، اختر App ID الخاص بك
2. فعّل **Apple Pay**
3. اضغط **Configure**
4. اختر Merchant ID الذي أنشأته
5. احفظ التغييرات

---

### الخطوة 2: Stripe Dashboard

#### 2.1 إضافة Domain
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. اذهب إلى **Settings** > **Payment methods**
3. اختر **Apple Pay**
4. اضغط **Add domain**
5. أدخل domain الخاص بك: `yourdomain.com`
6. حمّل ملف التحقق على الخادم:
   ```
   https://yourdomain.com/.well-known/apple-developer-merchantid-domain-association
   ```

#### 2.2 التحقق
- Stripe سيتحقق من الـ domain تلقائياً
- يجب أن ترى ✅ بجانب الـ domain

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

أضف:

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
6. أضف Merchant ID الخاص بك

---

### الخطوة 4: تحديث Flutter Code

**ملف: `lib/payment_screen.dart`**

```dart
// استبدل:
// دعم Google Pay
// ملاحظة: Apple Pay معطّل مؤقتاً لأنه يحتاج merchantIdentifier
// لتفعيله، راجع APPLE_PAY_SETUP.md
googlePay: const PaymentSheetGooglePay(
  merchantCountryCode: 'AE',
  testEnv: true,
),

// بـ:
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
2. أضف بطاقة
3. في وضع Test، استخدم بطاقات Stripe الاختبارية

#### 5.3 اختبار الدفع
1. شغّل التطبيق على iPhone
2. اذهب إلى شاشة الدفع
3. اضغط "Initialize Payment"
4. اضغط "Pay XX.XX AED"
5. يجب أن ترى خيار **Apple Pay** 🍎
6. اختره وأكمل الدفع

---

## 🔧 استكشاف الأخطاء

### خطأ: "merchantIdentifier must be specified"
**الحل:** أضف `merchantIdentifier` في الكود (الخطوة 4)

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

## 📝 ملخص سريع

### للاختبار الآن (بدون Apple Pay):
```
✅ البطاقات - يعمل
✅ Google Pay - يعمل
✅ Link - يعمل
❌ Apple Pay - معطّل (يحتاج إعداد)
```

### لتفعيل Apple Pay:
1. ✅ إنشاء Merchant ID في Apple Developer
2. ✅ إضافة Domain في Stripe
3. ✅ تحديث Entitlements و Info.plist
4. ✅ إضافة merchantIdentifier في الكود
5. ✅ اختبار على iPhone حقيقي

---

## 💡 نصائح

### للتطوير:
- اترك Apple Pay معطّلاً حتى تكون جاهزاً للنشر
- استخدم البطاقات و Google Pay للاختبار

### للإنتاج:
- أكمل جميع خطوات الإعداد
- اختبر على أجهزة حقيقية
- تأكد من Domain Verification

---

## 🔗 روابط مفيدة

- [Apple Pay Documentation](https://developer.apple.com/apple-pay/)
- [Stripe Apple Pay Guide](https://stripe.com/docs/apple-pay)
- [Flutter Stripe Apple Pay](https://pub.dev/packages/flutter_stripe#apple-pay)

---

## ✅ الحالة الحالية

| المكون | الحالة | الملاحظات |
|--------|--------|-----------|
| Merchant ID | ❌ غير موجود | يحتاج إنشاء |
| Domain Verification | ❌ غير مكتمل | يحتاج domain |
| Xcode Configuration | ❌ غير مكتمل | يحتاج تحديث |
| Flutter Code | ⏳ جاهز | ينتظر merchantIdentifier |

---

**آخر تحديث:** 19 أكتوبر 2024

💡 **نصيحة:** يمكنك استخدام التطبيق الآن مع البطاقات و Google Pay و Link. Apple Pay اختياري!

