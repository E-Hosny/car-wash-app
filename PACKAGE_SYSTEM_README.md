# نظام الباقات - Car Wash App

## نظرة عامة
تم تنفيذ نظام باقات شامل لتطبيق غسيل السيارات يتضمن:
- شراء باقات بنقاط
- ربط كل خدمة بعدد نقاط معين
- إدارة الباقات من لوحة التحكم
- دعم اللغتين العربية والإنجليزية

## الملفات المضافة

### Backend (Laravel)

#### 1. Migrations
- `2024_01_01_000001_create_packages_table.php` - جدول الباقات
- `2024_01_01_000002_create_service_points_table.php` - جدول نقاط الخدمات
- `2024_01_01_000003_create_user_packages_table.php` - جدول باقات المستخدمين
- `2024_01_01_000004_create_package_orders_table.php` - جدول طلبات الباقات

#### 2. Models
- `Package.php` - نموذج الباقة
- `ServicePoint.php` - نموذج نقاط الخدمة
- `UserPackage.php` - نموذج باقة المستخدم
- `PackageOrder.php` - نموذج طلب الباقة

#### 3. Controllers
- `API/PackageController.php` - API للعملاء
- `Admin/PackageController.php` - لوحة تحكم الأدمن

#### 4. Views (لوحة التحكم)
- `admin/packages/index.blade.php` - عرض الباقات
- `admin/packages/create.blade.php` - إضافة باقة
- `admin/packages/edit.blade.php` - تعديل الباقة
- `admin/packages/statistics.blade.php` - إحصائيات الباقات

#### 5. Translations
- `resources/lang/ar/packages.php` - الترجمة العربية
- `resources/lang/en/packages.php` - الترجمة الإنجليزية

#### 6. Seeders
- `PackageSeeder.php` - بيانات تجريبية للباقات

### Frontend (Flutter)

#### 1. Screens
- `screens/packages_screen.dart` - عرض الباقات
- `screens/my_package_screen.dart` - باقة المستخدم الحالية

#### 2. Updated Screens
- `order_request_screen.dart` - تحديث ليدعم الباقات
- `payment_screen.dart` - تحديث ليدعم طلبات الباقات

## كيفية التشغيل

### 1. تشغيل Migrations
```bash
cd car-wash-api
php artisan migrate
```

### 2. تشغيل Seeder
```bash
php artisan db:seed --class=PackageSeeder
```

### 3. أو استخدام الملف الجاهز
```bash
run_package_migration.bat
```

## الميزات

### للعملاء
1. **عرض الباقات**: تصفح الباقات المتاحة مع الأسعار والنقاط
2. **شراء الباقة**: شراء باقة جديدة عبر Stripe
3. **استخدام الباقة**: طلب خدمات باستخدام النقاط
4. **متابعة النقاط**: عرض النقاط المتبقية والمستهلكة
5. **سجل الباقات**: عرض تاريخ الباقات السابقة

### للأدمن
1. **إدارة الباقات**: إضافة، تعديل، حذف الباقات
2. **تعيين نقاط الخدمات**: ربط كل خدمة بعدد نقاط
3. **إحصائيات**: عرض إحصائيات الباقات والمبيعات
4. **تفعيل/تعطيل**: التحكم في حالة الباقات
5. **دعم اللغات**: واجهة بالعربية والإنجليزية

## API Endpoints

### الباقات
- `GET /api/packages` - عرض الباقات
- `GET /api/packages/{id}` - تفاصيل الباقة
- `POST /api/packages/{id}/purchase` - شراء الباقة
- `GET /api/packages/my/current` - باقة المستخدم الحالية
- `GET /api/packages/my/services` - الخدمات المتاحة
- `GET /api/packages/my/history` - سجل الباقات

### الطلبات (محدث)
- `POST /api/orders` - إنشاء طلب (يدعم الباقات)

## قاعدة البيانات

### جدول packages
- `id` - المعرف
- `name` - اسم الباقة
- `description` - وصف الباقة
- `price` - السعر
- `points` - عدد النقاط
- `image` - صورة الباقة
- `is_active` - حالة التفعيل

### جدول service_points
- `id` - المعرف
- `service_id` - معرف الخدمة
- `points_required` - النقاط المطلوبة

### جدول user_packages
- `id` - المعرف
- `user_id` - معرف المستخدم
- `package_id` - معرف الباقة
- `remaining_points` - النقاط المتبقية
- `total_points` - إجمالي النقاط
- `expires_at` - تاريخ الانتهاء
- `status` - الحالة (active/expired/cancelled)
- `payment_intent_id` - معرف الدفع
- `paid_amount` - المبلغ المدفوع
- `purchased_at` - تاريخ الشراء

### جدول package_orders
- `id` - المعرف
- `user_package_id` - معرف باقة المستخدم
- `order_id` - معرف الطلب
- `points_used` - النقاط المستخدمة

## ملاحظات تقنية

1. **الأمان**: يتم التحقق من ملكية الباقة وصلاحيتها
2. **التحديث الفوري**: النقاط تتحدث فوراً بعد كل طلب
3. **التحقق من النقاط**: لا يمكن استهلاك نقاط أكثر من المتاح
4. **دعم اللغات**: جميع النصوص مدعومة بالعربية والإنجليزية
5. **التوافق**: النظام متوافق مع النظام الحالي

## استكشاف الأخطاء

### مشكلة: جدول packages غير موجود
**الحل**: تشغيل migrations
```bash
php artisan migrate
```

### مشكلة: خطأ في الترجمة
**الحل**: التأكد من وجود ملفات الترجمة في `resources/lang/ar/packages.php` و `resources/lang/en/packages.php`

### مشكلة: لا تظهر الباقات في لوحة التحكم
**الحل**: 
1. التأكد من تشغيل migrations
2. تشغيل seeder
3. التحقق من وجود خدمات في قاعدة البيانات

## التطوير المستقبلي

1. **باقات شهرية تلقائية**: تجديد تلقائي للباقات
2. **باقات مخصصة**: باقات حسب احتياجات العميل
3. **نظام المكافآت**: نقاط إضافية للمستخدمين النشطين
4. **تقارير متقدمة**: تقارير مفصلة عن استخدام الباقات
5. **إشعارات**: إشعارات بانتهاء الباقة أو النقاط 