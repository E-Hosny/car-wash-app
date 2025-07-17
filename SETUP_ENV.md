# إعداد ملف .env لحل مشكلة Connection Error

## المشكلة
عند الضغط على "Buy Package" يظهر "Connection error" بسبب عدم وجود ملف `.env` أو عدم تكوين `BASE_URL` بشكل صحيح.

## الحل

### 1. إنشاء ملف .env
قم بإنشاء ملف `.env` في مجلد `assets/` بالمحتوى التالي:

```
# API Base URL - استبدل بالرابط الصحيح للخادم
BASE_URL=http://localhost:8000

# Stripe Configuration - استبدل بمفتاح Stripe الصحيح
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
```

### 2. تكوين BASE_URL
استبدل `http://localhost:8000` بالرابط الصحيح للخادم الخاص بك:

- للتطوير المحلي: `http://localhost:8000`
- للخادم المباشر: `https://your-domain.com`
- للخادم المحلي على الشبكة: `http://192.168.1.100:8000`

### 3. تكوين Stripe (اختياري)
إذا كنت تستخدم Stripe للدفع، استبدل `pk_test_your_stripe_publishable_key_here` بمفتاح Stripe الصحيح.

### 4. إعادة تشغيل التطبيق
بعد إنشاء الملف، أعد تشغيل التطبيق:

```bash
flutter clean
flutter pub get
flutter run
```

## ملاحظات
- تأكد من أن ملف `.env` موجود في مجلد `assets/`
- تأكد من أن الخادم يعمل على الرابط المحدد
- تأكد من أن التطبيق يمكنه الوصول إلى الخادم (لا توجد مشاكل في الشبكة أو الجدار الناري) 