# حل مشكلة Multi-Car Order

## المشكلة
كان هناك خطأ عند محاولة إنشاء طلب متعدد السيارات (multi-car order) في تطبيق `car_wash_app`. الخطأ كان:
```
The POST method is not supported for route api/orders/multi-car. Supported methods: GET, HEAD.
```

## السبب
المسار `api/orders/multi-car` لم يكن معرف في ملف `routes/api.php` ودالة `storeMultiCar` لم تكن موجودة في `OrderController`.

## الحل

### 1. إضافة المسار في routes/api.php
```php
Route::post('/orders/multi-car', [OrderController::class, 'storeMultiCar']);
```

### 2. إضافة دالة storeMultiCar في OrderController
تم إضافة دالة كاملة لمعالجة الطلبات متعددة السيارات مع:
- التحقق من ملكية السيارات للمستخدم
- حساب النقاط المطلوبة للباقات
- إنشاء طلب منفصل لكل سيارة
- إرسال إشعارات للمزودين

### 3. إصلاح مشاكل في Models
- إضافة حقل `services` إلى `PackageOrder` model
- إضافة migration لإضافة حقل `services` إلى جدول `package_orders`
- إصلاح حساب النقاط في `Service` model

### 4. تحسين FirebaseNotificationService
- إضافة دالة `sendNotification` لدعم إرسال إشعارات لعدة tokens

### 5. إصلاح حساب النقاط
تم إصلاح طريقة حساب النقاط من:
```php
$services->sum('points_required')
```
إلى:
```php
$services->sum(function($service) {
    return $service->servicePoint ? $service->servicePoint->points_required : 0;
});
```

## الملفات المعدلة

### Backend (Laravel API)
1. `car-wash-api/routes/api.php` - إضافة المسار
2. `car-wash-api/app/Http/Controllers/API/OrderController.php` - إضافة دالة storeMultiCar
3. `car-wash-api/app/Models/PackageOrder.php` - إضافة حقل services
4. `car-wash-api/app/Services/FirebaseNotificationService.php` - إضافة دالة sendNotification
5. `car-wash-api/database/migrations/2024_01_01_000004_create_package_orders_table.php` - إضافة حقل services
6. `car-wash-api/database/migrations/2025_01_15_000000_add_services_to_package_orders_table.php` - migration جديد

### Frontend (Flutter)
لا توجد تعديلات مطلوبة في التطبيق الأمامي لأنه كان يرسل الطلب بشكل صحيح.

## كيفية الاختبار

1. تأكد من تشغيل خادم Laravel API
2. افتح تطبيق Flutter
3. اذهب إلى صفحة Multi-Car Order
4. أضف سيارات وخدمات
5. حاول إنشاء الطلب
6. يجب أن يعمل الدفع بنجاح الآن

## ملاحظات مهمة

- تأكد من تشغيل migrations الجديدة
- تأكد من وجود بيانات في جداول `services` و `service_points`
- تأكد من أن المستخدم لديه سيارات مسجلة
- تأكد من أن الباقات تعمل بشكل صحيح إذا كنت تستخدم نظام الباقات

## استكشاف الأخطاء

إذا واجهت أي مشاكل:
1. تحقق من logs Laravel في `storage/logs/laravel.log`
2. تحقق من console Flutter للأخطاء
3. تأكد من أن جميع الـ models والعلاقات تعمل بشكل صحيح
4. تحقق من أن المسارات معرفة بشكل صحيح باستخدام `php artisan route:list` 