# مرجع سريع - طرق الدفع المتعددة
# Quick Reference - Multiple Payment Methods

## 🚀 الأوامر السريعة

### تشغيل المشروع
```bash
# Backend
cd c:/xampp/htdocs/car-wash-api
php artisan serve

# Frontend
cd c:/car_wash_app
flutter run
```

### اختبار API
```bash
cd c:/xampp/htdocs/car-wash-api
php test_payment_sheet.php
```

### تحديث قاعدة البيانات
```bash
cd c:/xampp/htdocs/car-wash-api
php artisan migrate
```

---

## 💳 بطاقات الاختبار السريعة

```
✅ نجاح:     4242 4242 4242 4242
✅ 3D Secure: 4000 0025 0000 3155
❌ فشل:      4000 0000 0000 0002

التاريخ: 12/34 | CVV: 123 | ZIP: 12345
```

---

## 📁 الملفات المهمة

### Backend:
```
app/Http/Controllers/API/PaymentController.php
app/Models/User.php
database/migrations/2024_10_19_000000_add_stripe_customer_id_to_users_table.php
```

### Frontend:
```
lib/services/stripe_service.dart
lib/payment_screen.dart
```

### التوثيق:
```
PAYMENT_METHODS_README_AR.md          ← ابدأ هنا!
MULTIPLE_PAYMENT_METHODS_IMPLEMENTATION.md
PAYMENT_TESTING_GUIDE.md
PRODUCTION_DEPLOYMENT_CHECKLIST.md
```

---

## 🔑 المفاتيح والإعدادات

### Backend (.env):
```env
STRIPE_PUBLISHABLE_KEY=pk_test_xxx  # للاختبار
STRIPE_SECRET_KEY=sk_test_xxx       # للاختبار
```

### Frontend (test_local.env):
```env
BASE_URL=http://127.0.0.1:8000
STRIPE_PUBLISHABLE_KEY=pk_test_xxx
```

---

## 🧪 اختبار سريع

### 1. اختبار API:
```bash
cd c:/xampp/htdocs/car-wash-api
php test_payment_sheet.php
```

**النتيجة المتوقعة:**
```
✅ client_secret: موجود
✅ ephemeral_key: موجود
✅ customer: موجود
✅ payment_intent_id: موجود
```

### 2. اختبار التطبيق:
1. شغّل التطبيق
2. اختر خدمة
3. اضغط "Initialize Payment"
4. اضغط "Pay XX.XX AED"
5. اختر طريقة دفع
6. أكمل الدفع

---

## 🐛 حل المشاكل السريع

### API لا يعمل:
```bash
# تحقق من الخادم
php artisan serve

# تحقق من التوكن
php artisan tinker --execute="echo \App\Models\User::first()->createToken('test')->plainTextToken;"
```

### التطبيق لا يتصل:
```dart
// تحقق من BASE_URL في test_local.env
BASE_URL=http://127.0.0.1:8000  // ✅ صحيح
BASE_URL=http://localhost:8000  // ❌ قد لا يعمل على Android
```

### PaymentSheet لا يظهر:
```dart
// تحقق من:
1. تم الضغط على "Initialize Payment"
2. _paymentIntentClientSecret != null
3. _ephemeralKey != null
4. _customerId != null
```

---

## 📊 التحقق السريع

### Stripe Dashboard:
```
dashboard.stripe.com → Payments
```

### قاعدة البيانات:
```sql
-- آخر 5 طلبات
SELECT * FROM orders ORDER BY created_at DESC LIMIT 5;

-- العملاء مع stripe_customer_id
SELECT id, name, stripe_customer_id FROM users WHERE stripe_customer_id IS NOT NULL;
```

### Laravel Logs:
```bash
tail -f storage/logs/laravel.log
```

---

## 🎯 طرق الدفع المدعومة

| الطريقة | الحالة | ملاحظات |
|---------|--------|---------|
| 💳 Cards | ✅ | جميع البطاقات |
| 🍎 Apple Pay | ✅ | iOS فقط |
| 📱 Google Pay | ✅ | Android فقط |
| 🔗 Link | ✅ | جميع المنصات |

---

## 📞 روابط مهمة

- [Stripe Dashboard](https://dashboard.stripe.com)
- [Stripe Docs](https://stripe.com/docs/payments/payment-sheet)
- [Flutter Stripe](https://pub.dev/packages/flutter_stripe)

---

## ⚡ نصائح سريعة

1. **للاختبار:** استخدم `4242 4242 4242 4242`
2. **Apple Pay:** يحتاج جهاز iOS حقيقي
3. **Google Pay:** يحتاج جهاز Android حقيقي
4. **للإنتاج:** غيّر المفاتيح من test إلى live

---

**آخر تحديث:** 19 أكتوبر 2024

🎉 **كل شيء جاهز للاستخدام!**

