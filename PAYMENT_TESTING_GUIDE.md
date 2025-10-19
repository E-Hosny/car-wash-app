# دليل اختبار طرق الدفع المتعددة
# Payment Methods Testing Guide

## ✅ اختبار API (Backend) - تم بنجاح

تم اختبار الـ API وتأكيد أنه يرجع جميع البيانات المطلوبة:
- ✅ Client Secret
- ✅ Ephemeral Key
- ✅ Customer ID
- ✅ Payment Intent ID

## 📱 اختبار التطبيق (Flutter App)

### الخطوة 1: تشغيل التطبيق
```bash
cd c:/car_wash_app
flutter run
```

### الخطوة 2: اختبار عملية الدفع الكاملة

#### 2.1 تسجيل الدخول
- افتح التطبيق
- سجل دخول بحساب اختبار

#### 2.2 إنشاء طلب
- اختر خدمة غسيل
- اختر سيارة
- اختر موعد
- اضغط على "Book Now"

#### 2.3 شاشة الدفع
- اضغط على "Initialize Payment"
- انتظر حتى يتم إنشاء Payment Intent
- ستظهر رسالة "Multiple Payment Methods Available"
- اضغط على زر "Pay XX.XX AED"

#### 2.4 PaymentSheet
ستظهر شاشة الدفع من Stripe مع الخيارات التالية:

## 🧪 طرق الاختبار

### 1️⃣ اختبار البطاقات (Cards)

#### بطاقات اختبار Stripe:

**✅ بطاقة ناجحة:**
```
Card Number: 4242 4242 4242 4242
Expiry: 12/34 (أي تاريخ مستقبلي)
CVC: 123 (أي 3 أرقام)
ZIP: 12345 (أي رمز بريدي)
```

**✅ بطاقة مع 3D Secure:**
```
Card Number: 4000 0025 0000 3155
Expiry: 12/34
CVC: 123
ZIP: 12345
```
سيطلب منك التحقق الإضافي، اضغط "Complete" أو "Fail" للاختبار.

**❌ بطاقة مرفوضة:**
```
Card Number: 4000 0000 0000 0002
Expiry: 12/34
CVC: 123
ZIP: 12345
```

**💰 رصيد غير كافٍ:**
```
Card Number: 4000 0000 0000 9995
Expiry: 12/34
CVC: 123
ZIP: 12345
```

**🔒 بطاقة مسروقة:**
```
Card Number: 4000 0000 0000 9979
Expiry: 12/34
CVC: 123
ZIP: 12345
```

### 2️⃣ اختبار Apple Pay 🍎

**المتطلبات:**
- جهاز iOS حقيقي (لا يعمل على المحاكي)
- بطاقة مضافة إلى Apple Wallet
- في وضع الاختبار، يمكن استخدام بطاقات اختبار Stripe

**خطوات الاختبار:**
1. افتح شاشة الدفع
2. اضغط على "Pay XX.XX AED"
3. اختر "Apple Pay" من الخيارات
4. أكمل الدفع باستخدام Face ID/Touch ID
5. تحقق من نجاح الدفع

### 3️⃣ اختبار Google Pay 

**المتطلبات:**
- جهاز Android حقيقي
- Google Pay مثبت ومفعل
- بطاقة مضافة إلى Google Pay

**خطوات الاختبار:**
1. افتح شاشة الدفع
2. اضغط على "Pay XX.XX AED"
3. اختر "Google Pay" من الخيارات
4. أكمل الدفع
5. تحقق من نجاح الدفع

### 4️⃣ اختبار Link 🔗

**ما هو Link؟**
Link هي طريقة دفع سريعة من Stripe تحفظ معلومات الدفع.

**خطوات الاختبار:**
1. افتح شاشة الدفع
2. اضغط على "Pay XX.XX AED"
3. إذا كنت تستخدم Link لأول مرة:
   - أدخل بريدك الإلكتروني
   - أدخل بيانات البطاقة
   - احفظ المعلومات في Link
4. في المرات القادمة:
   - سيتم ملء البيانات تلقائياً
   - فقط أكد الدفع

## 📊 سيناريوهات الاختبار

### ✅ سيناريو 1: دفع ناجح
1. استخدم بطاقة `4242 4242 4242 4242`
2. أكمل الدفع
3. **النتيجة المتوقعة:**
   - ظهور رسالة "Thank You!"
   - الانتقال إلى صفحة الطلبات
   - ظهور الطلب بحالة "Paid"

### ❌ سيناريو 2: دفع مرفوض
1. استخدم بطاقة `4000 0000 0000 0002`
2. حاول إكمال الدفع
3. **النتيجة المتوقعة:**
   - ظهور رسالة خطأ
   - البقاء في شاشة الدفع
   - إمكانية المحاولة مرة أخرى

### 🔙 سيناريو 3: إلغاء الدفع
1. افتح PaymentSheet
2. اضغط على زر الإغلاق (X)
3. **النتيجة المتوقعة:**
   - ظهور رسالة "Payment was cancelled"
   - البقاء في شاشة الدفع
   - إمكانية المحاولة مرة أخرى

### 🔒 سيناريو 4: 3D Secure
1. استخدم بطاقة `4000 0025 0000 3155`
2. أكمل بيانات البطاقة
3. **النتيجة المتوقعة:**
   - ظهور شاشة تحقق إضافية
   - اختر "Complete" للنجاح
   - أو "Fail" للفشل

## 🔍 التحقق من النتائج

### في التطبيق:
1. **شاشة الطلبات:**
   - تحقق من ظهور الطلب
   - تحقق من حالة الدفع (Paid/Pending)

2. **Console Logs:**
   ```
   ✅ Payment Intent created successfully
   Client Secret: pi_xxx...
   Customer ID: cus_xxx
   Starting PaymentSheet presentation...
   PaymentSheet initialized, presenting...
   Payment confirmed successfully via PaymentSheet
   ```

### في Stripe Dashboard:
1. افتح [dashboard.stripe.com](https://dashboard.stripe.com)
2. انتقل إلى **Payments**
3. ابحث عن الدفعة الأخيرة
4. تحقق من:
   - المبلغ
   - الحالة (Succeeded/Failed)
   - طريقة الدفع المستخدمة
   - Customer ID

### في قاعدة البيانات:
```sql
-- التحقق من الطلب
SELECT * FROM orders WHERE id = [order_id];

-- التحقق من حالة الدفع
SELECT id, payment_status, payment_intent_id, paid_at 
FROM orders 
ORDER BY created_at DESC 
LIMIT 5;

-- التحقق من stripe_customer_id
SELECT id, name, email, stripe_customer_id 
FROM users 
WHERE stripe_customer_id IS NOT NULL;
```

## 🐛 استكشاف الأخطاء

### خطأ: "Payment intent not created"
**الحل:**
- تأكد من الضغط على "Initialize Payment" أولاً
- تحقق من اتصال الإنترنت
- تحقق من صلاحية التوكن

### خطأ: "Failed to create payment intent"
**الحل:**
- تحقق من إعدادات Stripe API Keys
- تحقق من أن الـ Backend يعمل
- راجع logs في Laravel (`storage/logs/laravel.log`)

### خطأ: "Missing required payment data"
**الحل:**
- تحقق من أن API يرجع جميع الحقول:
  - client_secret
  - ephemeral_key
  - customer
  - payment_intent_id

### PaymentSheet لا يظهر
**الحل:**
- تحقق من تهيئة Stripe في `initState()`
- تحقق من صلاحية `STRIPE_PUBLISHABLE_KEY`
- راجع console logs

## 📝 قائمة التحقق النهائية

قبل النشر للإنتاج، تأكد من:

- [ ] اختبار جميع بطاقات الاختبار
- [ ] اختبار Apple Pay (على جهاز حقيقي)
- [ ] اختبار Google Pay (على جهاز حقيقي)
- [ ] اختبار Link
- [ ] اختبار سيناريوهات الفشل
- [ ] اختبار الإلغاء
- [ ] التحقق من Stripe Dashboard
- [ ] التحقق من قاعدة البيانات
- [ ] اختبار مع مستخدمين مختلفين
- [ ] اختبار مع مبالغ مختلفة

## 🚀 الانتقال للإنتاج

عند الاستعداد للإنتاج:

1. **تحديث Stripe Keys:**
   ```env
   STRIPE_PUBLISHABLE_KEY=pk_live_xxx
   STRIPE_SECRET_KEY=sk_live_xxx
   ```

2. **تحديث Google Pay:**
   ```dart
   googlePay: PaymentSheetGooglePay(
     merchantCountryCode: 'AE',
     testEnv: false, // ✅ غيّر إلى false
   ),
   ```

3. **إعداد Apple Pay:**
   - سجل Merchant ID
   - أضف Domain في Stripe
   - حدّث `Info.plist`

4. **اختبار نهائي:**
   - استخدم بطاقات حقيقية
   - تحقق من جميع طرق الدفع
   - راقب Stripe Dashboard

## 📞 الدعم

إذا واجهت أي مشاكل:
1. راجع [Stripe Documentation](https://stripe.com/docs)
2. تحقق من [Flutter Stripe Issues](https://github.com/flutter-stripe/flutter_stripe/issues)
3. راجع logs في Laravel و Flutter

---

**آخر تحديث:** 19 أكتوبر 2024
**الحالة:** ✅ جاهز للاختبار

