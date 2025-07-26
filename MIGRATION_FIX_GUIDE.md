# دليل حل مشكلة Migration

## المشكلة
عند تشغيل `php artisan migrate` ظهر خطأ:
```
SQLSTATE[42S01]: Base table or view already exists: 1050 Table 'order_cars' already exists
```

## السبب
جدول `order_cars` موجود بالفعل في قاعدة البيانات، مما يعني أن migration تم تشغيله مسبقاً.

## الحل

### الخطوة 1: التحقق من حالة Migrations
```bash
cd /c/xampp/htdocs/car-wash-api
php artisan migrate:status
```

### الخطوة 2: تشغيل Migration الجديد
```bash
php artisan migrate
```

إذا ظهر خطأ، جرب:
```bash
php artisan migrate --force
```

### الخطوة 3: التحقق من الجداول
إذا استمرت المشكلة، يمكن التحقق من الجداول الموجودة:

```sql
-- في phpMyAdmin أو MySQL CLI
SHOW TABLES LIKE 'order_cars';
SHOW TABLES LIKE 'order_car_service';
SHOW TABLES LIKE 'package_orders';
```

### الخطوة 4: إصلاح يدوي (إذا لزم الأمر)

إذا كان جدول `order_cars` موجود ولكن `order_car_service` غير موجود:

```sql
-- إنشاء جدول order_car_service
CREATE TABLE `order_car_service` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `order_car_id` bigint unsigned NOT NULL,
  `service_id` bigint unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `order_car_service_order_car_id_foreign` (`order_car_id`),
  KEY `order_car_service_service_id_foreign` (`service_id`),
  CONSTRAINT `order_car_service_order_car_id_foreign` FOREIGN KEY (`order_car_id`) REFERENCES `order_cars` (`id`) ON DELETE CASCADE,
  CONSTRAINT `order_car_service_service_id_foreign` FOREIGN KEY (`service_id`) REFERENCES `services` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### الخطوة 5: التحقق من حقل services في package_orders

```sql
-- التحقق من وجود حقل services
DESCRIBE package_orders;

-- إضافة الحقل إذا لم يكن موجود
ALTER TABLE `package_orders` ADD COLUMN `services` JSON NULL AFTER `points_used`;
```

## اختبار النظام

بعد إصلاح قاعدة البيانات:

1. **اختبار إنشاء طلب متعدد السيارات**:
   - افتح تطبيق Flutter
   - اذهب إلى Multi-Car Order
   - أضف سيارتين أو أكثر
   - أنشئ الطلب

2. **التحقق من النتيجة**:
   - اذهب إلى صفحة الطلبات
   - يجب أن ترى طلب واحد فقط مع جميع السيارات

## استكشاف الأخطاء

### إذا ظهر خطأ في العلاقات:
```bash
php artisan config:clear
php artisan cache:clear
php artisan route:clear
```

### إذا ظهر خطأ في Model:
تأكد من أن جميع الـ Models موجودة:
- `OrderCar.php`
- `Order.php` (محدث)
- `PackageOrder.php` (محدث)

### إذا ظهر خطأ في Controller:
تأكد من أن `OrderController.php` محدث مع دالة `storeMultiCar` الجديدة.

## ملاحظات مهمة

- الطلبات القديمة ستبقى كما هي
- الطلبات الجديدة ستكون موحدة
- تأكد من وجود بيانات في جداول `services` و `service_points`
- تأكد من أن المستخدم لديه سيارات مسجلة

## الاتصال بالدعم

إذا استمرت المشكلة، يمكن:
1. مشاركة رسالة الخطأ الكاملة
2. مشاركة نتيجة `php artisan migrate:status`
3. مشاركة هيكل الجداول من phpMyAdmin 